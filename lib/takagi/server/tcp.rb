# frozen_string_literal: true

require 'socket'
require_relative '../response_builder'

module Takagi
  module Server
    # TCP server implementation for CoAP over TCP
    class Tcp
      def initialize(port: 5683, worker_threads: 2,
                     middleware_stack: nil, router: nil, logger: nil, watcher: nil, sender: nil)
        @port = port
        @worker_threads = worker_threads
        @middleware_stack = middleware_stack || Takagi::MiddlewareStack.instance
        @router = router || Takagi::Router.instance
        @logger = logger || Takagi.logger
        @watcher = watcher || Takagi::Observer::Watcher.new(interval: 1)

        Initializer.run!

        @server = TCPServer.new('0.0.0.0', @port)
        @sender = sender || Takagi::Network::TcpSender.instance
      end

      def run!
        @logger.info "Starting Takagi TCP server on port #{@port}"
        @workers = []
        @watcher.start
        trap('INT') { shutdown! }

        loop do
          break if @shutdown_called

          begin
            @logger.debug "Waiting for client connection..."
            client = @server.accept
            @logger.debug "Client connected from #{client.peeraddr.inspect}"
          rescue IOError, SystemCallError => e
            @logger.error "TCP server accept failed: #{e.class}: #{e.message}"
            @logger.debug "TCP server accept loop exiting: #{e.message}" if @shutdown_called
            break
          end

          @logger.debug "Spawning handler thread for client"
          Thread.new(client) do |sock|
            begin
              handle_connection(sock)
            rescue => e
              @logger.error "Handler thread crashed: #{e.class}: #{e.message}"
              @logger.debug e.backtrace.join("\n")
            end
          end
        end
        @logger.info "TCP server stopped"
      end

      def shutdown!
        return if @shutdown_called

        @shutdown_called = true
        @watcher.stop
        @server.close if @server && !@server.closed?
      end

      private

      def handle_connection(sock)
        # RFC 8323: Exchange CSM (Capabilities and Settings Message) first
        csm_sent = false

        loop do
          inbound_request = read_request(sock)
          break unless inbound_request

          @logger.debug "Received request from client: #{inbound_request.inspect}"

          # Handle CSM message (7.01) from client
          if inbound_request.code == CoAP::Signaling::CSM
            @logger.debug "Received CSM from client"
            unless csm_sent
              send_csm(sock)
              csm_sent = true
            end
            next
          end

          # RFC 8323 §5.1: Server should send CSM before processing first request
          unless csm_sent
            @logger.debug "Sending CSM to client before processing first request"
            send_csm(sock)
            csm_sent = true
          end

          response = build_response(inbound_request)
          transmit_response(sock, response)
        end
        @logger.debug "Client connection closed gracefully"
      rescue StandardError => e
        @logger.error "TCP handle_connection failed: #{e.message}"
        @logger.debug e.backtrace.join("\n")
      ensure
        sock.close unless sock.closed?
      end

      # Read request using RFC 8323 §3.3 variable-length framing
      # Length encoding:
      # - 0-12: length is in first 4 bits of first byte
      # - 13-268: first nibble = 13, next byte = length - 13
      # - 269-65804: first nibble = 14, next 2 bytes = length - 269
      # - 65805+: first nibble = 15, next 4 bytes = length - 65805
      def read_request(sock)
        @logger.debug "read_request: socket is open, attempting to read first byte..."

        # Check how many bytes are available to read
        if sock.respond_to?(:nread)
          bytes_available = sock.nread rescue 0
          @logger.debug "read_request: #{bytes_available} bytes available in buffer"
        end

        first_byte_data = sock.read(1)
        if first_byte_data.nil?
          @logger.debug "read_request: socket returned nil (connection closed or EOF)"
          return nil
        end

        if first_byte_data.empty?
          @logger.debug "read_request: socket returned empty string"
          return nil
        end

        first_byte = first_byte_data.unpack1('C')
        len_nibble = (first_byte >> 4) & 0x0F
        tkl        = first_byte & 0x0F

        length = case len_nibble
                 when 0..12
                   len_nibble
                 when 13
                   ext = sock.read(1) or return
                   ext.unpack1('C') + 13
                 when 14
                   ext = sock.read(2) or return
                   ext.unpack1('n') + 269
                 when 15
                   ext = sock.read(4) or return
                   ext.unpack1('N') + 65_805
                 end

        @logger.debug "read_request: message length=#{length} bytes (tkl=#{tkl})"

        # ✅ ČTI PŘESNĚ `length` BAJTŮ (už BEZ rámcového bajtu)
        data = sock.read(length)
        if data.nil? || data.bytesize != length
          @logger.error "read_request: Incomplete message (expected #{length}, got #{data&.bytesize || 0})"
          return nil
        end

        # ✅ Minimální validace: musí být prostor aspoň na Code
        if length < 1
          @logger.error "read_request: Invalid length (<1)"
          return nil
        end

        @logger.debug "read_request: Successfully read #{length} bytes (#{sock.nread rescue 0} remain)"

        # ✅ NEVRACEJ rámcový bajt do Inbound
        Takagi::Message::Inbound.new(data, transport: :tcp)
      rescue IOError, Errno::ECONNRESET => e
        @logger.debug "read_request: Socket error (#{e.class}: #{e.message})"
        nil
      end

      def build_response(inbound_request)
        result = @middleware_stack.call(inbound_request)
        ResponseBuilder.build(inbound_request, result, logger: @logger)
      end

      def transmit_response(sock, response)
        bytes = response.to_bytes(transport: :tcp)
        framed = encode_tcp_frame(bytes)
        written = sock.write(framed)
        sock.flush
        @logger.debug "Sent #{framed.bytesize} bytes to client (wrote #{written} bytes)"
      end

      # Send CSM (Capabilities and Settings Message) to client
      # RFC 8323 §5.3.1
      def send_csm(sock)
        csm = build_csm_message
        bytes = csm.to_bytes(transport: :tcp)
        framed = encode_tcp_frame(bytes)
        written = sock.write(framed)
        sock.flush
        @logger.debug "Sent CSM to client (#{framed.bytesize} bytes, wrote #{written} bytes)"
      end

      # Encode TCP frame with RFC 8323 §3.3 variable-length encoding
      # The first byte of data has format: Len (upper 4 bits) | TKL (lower 4 bits)
      # We need to update the Len nibble and potentially add extension bytes
      def encode_tcp_frame(data)
        return ''.b if data.empty?

        @logger.debug "encode_tcp_frame: input data (#{data.bytesize} bytes): #{data.inspect}"

        # Extract TKL from first byte
        first_byte = data.bytes[0]
        tkl = first_byte & 0x0F
        length = data.bytesize

        @logger.debug "encode_tcp_frame: first_byte=0x#{first_byte.to_s(16)}, tkl=#{tkl}, length=#{length}"

        result = if length <= 12
                   # Length fits in first nibble, update first byte
                   new_first_byte = (length << 4) | tkl
                   @logger.debug "encode_tcp_frame: new_first_byte=0x#{new_first_byte.to_s(16)}"
                   [new_first_byte].pack('C') + data[1..]
                 elsif length <= 268
                   # Length nibble = 13, extension = 1 byte
                   new_first_byte = (13 << 4) | tkl
                   ext_byte = length - 13
                   [new_first_byte, ext_byte].pack('CC') + data[1..]
                 elsif length <= 65_804
                   # Length nibble = 14, extension = 2 bytes
                   new_first_byte = (14 << 4) | tkl
                   ext_bytes = length - 269
                   [new_first_byte].pack('C') + [ext_bytes].pack('n') + data[1..]
                 else
                   # Length nibble = 15, extension = 4 bytes
                   new_first_byte = (15 << 4) | tkl
                   ext_bytes = length - 65_805
                   [new_first_byte].pack('C') + [ext_bytes].pack('N') + data[1..]
                 end

        @logger.debug "encode_tcp_frame: output (#{result.bytesize} bytes): #{result.inspect}"
        result
      end

      # Build CSM message with server capabilities
      # RFC 8323 §5.3.1
      def build_csm_message
        # CSM code is 7.01 (225)
        # Options: Max-Message-Size (2), Block-Wise-Transfer (4)
        # Both are uint values, not packed binary
        options = {
          2 => 8_388_864,  # Max-Message-Size: 8MB (integer value, will be encoded properly)
          4 => 0           # Block-Wise-Transfer supported (0 means supported)
        }
        Takagi::Message::Outbound.new(
          code: CoAP::Signaling::CSM,
          payload: '',
          token: '',
          message_id: 0,
          type: 0,  # No type field in TCP CoAP
          options: options,
          transport: :tcp
        )
      end
    end
  end
end
