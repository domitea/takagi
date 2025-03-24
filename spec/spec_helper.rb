# frozen_string_literal: true

require "takagi"

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  Dir["#{File.dirname(__FILE__)}/**/*.rb"].each { |file| require file }

  def find_free_port
    socket = UDPSocket.new
    socket.bind("127.0.0.1", 0)
    port = socket.addr[1]
    socket.close
    port
  end

  def send_coap_request(_type, method, path, payload = nil)
    message_id = rand(0..0xFFFF)

    method_code = case method
                  when :get then 1
                  when :post then 2
                  when :put then 3
                  when :delete then 4
                  else 0
                  end

    header = [0x40, method_code, (message_id >> 8) & 0xFF, message_id & 0xFF].pack("C*")
    options = encode_uri_path(path)

    packet = header + options
    packet += "\xFF#{payload}".b if payload

    @client.send(packet, 0, *@server_address)
    response, = @client.recvfrom(1024)
    response
  end

  def encode_uri_path(path)
    segments = path.split("/").reject(&:empty?)
    last_option_number = 0
    encoded = "".b

    segments.each do |segment|
      option_number = 11 # Uri-Path
      delta = option_number - last_option_number
      length = segment.bytesize

      raise "Segment too long" if length > 12 || delta > 12

      option_byte = (delta << 4) | length
      encoded << option_byte.chr
      encoded << segment

      last_option_number = option_number
    end

    encoded
  end
end
