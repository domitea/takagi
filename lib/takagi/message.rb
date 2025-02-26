# frozen_string_literal: true

module Takagi
  class Message
    def self.parse(data)
      version_type_tkl = data.bytes[0]
      code = data.bytes[1]
      message_id = data.bytes[2..3].pack("C*").unpack("n").first
      token_length = version_type_tkl & 0x0F
      token = data[4, token_length] || "".b
      path = extract_uri_path(data.bytes[(4 + token_length)..])
      payload_start = data.index("\xFF".b)
      payload = payload_start ? data[(payload_start + 1)..-1].force_encoding("ASCII-8BIT") : nil

      { method: coap_code_to_method(code), path: path, token: token, payload: payload }
    end

    def self.build_response(code, payload, token)
      message_id = rand(0..0xFFFF)
      response_code = coap_method_to_code(code)
      header = [0x60 | (token.bytesize & 0x0F), response_code, (message_id >> 8) & 0xFF, message_id & 0xFF].pack("C*")

      payload_marker = "\xFF".b
      payload_data = payload.to_json.force_encoding("ASCII-8BIT")
      header + token + payload_marker + payload_data
    end

    private

    def self.coap_code_to_method(code)
      case code
      when 1 then "GET"
      when 2 then "POST"
      when 3 then "PUT"
      when 4 then "DELETE"
      else "UNKNOWN"
      end
    end

    def self.coap_method_to_code(code)
      case code
      when 2.05 then 69  # 2.05 Content
      when 4.04 then 132 # 4.04 Not Found
      else 160 # Generic response
      end
    end

    def self.extract_uri_path(bytes)
      path_segments = [] # Místo prostého stringu uložíme segmenty do pole
      options_start = 0
      last_option = 0

      while options_start < bytes.length && bytes[options_start] != 255 # 0xFF = start payloadu
        delta = (bytes[options_start] >> 4) & 0x0F  # Číslo opce
        len = bytes[options_start] & 0x0F           # Délka dat
        options_start += 1

        option_number = last_option + delta
        if option_number == 11 # Uri-Path (11 znamená část cesty)
          segment = bytes[options_start, len].pack("C*").b
          path_segments << segment # Ukládáme jednotlivé segmenty do pole
          puts "Parsed path segment: #{segment}" # Debug výpis
        end

        options_start += len
        last_option = option_number
      end

      # Spojíme segmenty pomocí `/` a zajistíme, že začne `/`
      path = "/#{path_segments.join("/")}"

      path.force_encoding("UTF-8") if path.valid_encoding?
      puts "Final parsed path: #{path}"  # Debug výpis celé cesty
      path
    end
  end
end
