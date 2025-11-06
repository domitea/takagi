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
        # RFC 8323 §5.3: Read client CSM first, then send server CSM
        csm_received = false

        loop do
          inbound_request = read_request(sock)
          break unless inbound_request

          @logger.debug "Received request from client: #{inbound_request.inspect}"

          case inbound_request.code
          when CoAP::Signaling::CSM
            @logger.debug "Received CSM from client"
            unless csm_received
              # Send our CSM in response to client's CSM
              send_csm(sock)
              csm_received = true
            end
            next
          when CoAP::Signaling::PING
            @logger.debug "Received PING from client"
            send_pong(sock, inbound_request)
            next
          when CoAP::Signaling::RELEASE, CoAP::Signaling::ABORT
            @logger.debug "Received #{Takagi::CoAP::Registries::Signaling.name_for(inbound_request.code)} from client, closing connection"
            break
          end

          # Process regular CoAP requests
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
                   ext_value = ext.unpack1('C')
                   @logger.debug "read_request: extended length byte=0x#{ext_value.to_s(16)}"
                   ext_value + 13
                 when 14
                   ext = sock.read(2) or return
                   ext_value = ext.unpack1('n')
                   @logger.debug "read_request: extended length bytes=0x#{ext_value.to_s(16)}"
                   ext_value + 269
                 when 15
                   ext = sock.read(4) or return
                   ext_value = ext.unpack1('N')
                   @logger.debug "read_request: extended length bytes=0x#{ext_value.to_s(16)}"
                   ext_value + 65_805
                 end

        @logger.debug "read_request: first_byte=0x#{first_byte.to_s(16)}, message length=#{length} bytes (tkl=#{tkl})"

        # RFC 8323 §3.3: Length field = size of (Options + Payload)
        # We need to read: Code (1 byte) + Token (tkl bytes) + Options + Payload (length bytes)
        code_size = 1
        bytes_to_read = code_size + tkl + length
        data = +''.b
        remaining = bytes_to_read
        while remaining.positive?
          begin
            chunk = sock.readpartial(remaining)
          rescue IO::WaitReadable
            IO.select([sock])
            retry
          rescue EOFError
            @logger.error "read_request: Incomplete message (expected #{length}, got #{data.bytesize})"
            return nil
          end

          @logger.debug "read_request: received chunk=#{chunk.bytes.map { |b| format('%02x', b) }.join}"
          data << chunk
          remaining -= chunk.bytesize
        end

        # Validate: must have space for at least Code byte
        if bytes_to_read < 1
          @logger.error "read_request: Invalid message size (<1)"
          return nil
        end

        bytes_remaining = sock.nread rescue 0
        @logger.debug "read_request: Successfully read #{bytes_to_read} bytes (#{bytes_remaining} remain)"

        # NOTE: With the corrected length calculation, the CSM workaround is no longer needed
        # The bytes_remaining are likely from the next message in the TCP stream, not part of current message

        packet = first_byte_data + data
        @logger.debug "read_request: full packet=#{packet.bytes.map { |b| format('%02x', b) }.join}"

        Takagi::Message::Inbound.new(packet, transport: :tcp)
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

      def send_pong(sock, request)
        pong = Takagi::Message::Outbound.new(
          code: CoAP::Signaling::PONG,
          payload: '',
          token: request.token,
          message_id: 0,
          type: 0,
          options: {},
          transport: :tcp
        )

        bytes = pong.to_bytes(transport: :tcp)
        framed = encode_tcp_frame(bytes)
        written = sock.write(framed)
        sock.flush
        @logger.debug "Sent PONG to client (#{framed.bytesize} bytes, wrote #{written} bytes)"
      end

      # Encode TCP frame with RFC 8323 §3.3 variable-length encoding
      # The first byte of data has format: Len (upper 4 bits) | TKL (lower 4 bits)
      # We need to update the Len nibble and potentially add extension bytes
      # NOTE: The Length field counts only Options + Payload, NOT Code or Token
      def encode_tcp_frame(data)
        return ''.b if data.empty?

        @logger.debug "encode_tcp_frame: input data (#{data.bytesize} bytes): #{data.inspect}"

        # Extract TKL from first byte
        first_byte = data.getbyte(0)
        tkl = first_byte & 0x0F

        # RFC 8323 §3.3: Length = size of (Options + Payload)
        # data structure: first_byte(1) + code(1) + token(tkl) + options + payload
        # So: payload_length = total - 1 (first_byte) - 1 (code) - tkl (token)
        code_size = 1
        payload_length = [data.bytesize - 1 - code_size - tkl, 0].max

        @logger.debug "encode_tcp_frame: first_byte=0x#{first_byte.to_s(16)}, tkl=#{tkl}, payload_length=#{payload_length}"

        body = data.byteslice(1, data.bytesize - 1) || ''.b

        result =
          if payload_length <= 12
            new_first_byte = (payload_length << 4) | tkl
            @logger.debug "encode_tcp_frame: new_first_byte=0x#{new_first_byte.to_s(16)}"
            [new_first_byte].pack('C') + body
          elsif payload_length <= 268
            new_first_byte = (13 << 4) | tkl
            extension = payload_length - 13
            [new_first_byte, extension].pack('CC') + body
          elsif payload_length <= 65_804
            new_first_byte = (14 << 4) | tkl
            extension = payload_length - 269
            [new_first_byte].pack('C') + [extension].pack('n') + body
          else
            new_first_byte = (15 << 4) | tkl
            extension = payload_length - 65_805
            [new_first_byte].pack('C') + [extension].pack('N') + body
          end

        @logger.debug "encode_tcp_frame: output (#{result.bytesize} bytes): #{result.inspect}"
        result
      end

      # Build CSM message with server capabilities
      # RFC 8323 §5.3.1
      def build_csm_message
        # CSM code is 7.01 (225)
        # Options: Max-Message-Size (2), Block-Wise-Transfer (4)
        # Both are required for compatibility with coap-client-gnutls
        options = {
          2 => [8_388_864],  # Max-Message-Size: 8MB
          4 => ['']          # Block-Wise-Transfer supported (empty string for zero-length option)
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
