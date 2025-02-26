# frozen_string_literal: true

require "rack"
require "sequel"
require "socket"
require "json"

module Takagi
  class Base
    @@routes = {}

    def self.get(path, &block)
      @@routes["GET #{path}"] = block
    end

    def self.post(path, &block)
      @@routes["POST #{path}"] = block
    end

    def self.handle_request(method, path, token, payload = nil)
      puts "Registered routes: #{@@routes.keys.inspect}" # Debug výpis
      puts "Looking for route: #{method} #{path}"

      # Hledání přesného shody
      if @@routes.key?("#{method} #{path}")
        route = @@routes["#{method} #{path}"]
        params = {}
      else
        # Hledání dynamických rout
        route, params = match_dynamic_route(method, path)
      end

      return build_coap_response(4.04, { error: "Not Found" }, token) unless route

      # Parsujeme payload, pokud existuje
      params.merge!(JSON.parse(payload)) if payload

      response = route.call(params)
      build_coap_response(2.05, response, token)
    end

    def self.run!(port: 5683)
      server = UDPSocket.new
      server.bind("0.0.0.0", port)
      puts "Takagi running on CoAP://0.0.0.0:#{port}"

      loop do
        data, addr = server.recvfrom(1024)
        data.force_encoding("ASCII-8BIT")
        puts "Recieved data #{data.bytes}"
        method, path, payload = parse_coap_request(data)

        response = handle_request(method, path, payload)
        server.send(response, 0, addr[3], addr[1])
      end
    end

    def self.match_dynamic_route(method, path)
      @@routes.each do |route_key, block|
        route_method, route_path = route_key.split(" ", 2)

        next unless route_method == method # Musí odpovídat metoda (GET, POST atd.)

        route_parts = route_path.split("/")
        path_parts = path.split("/")

        next unless route_parts.length == path_parts.length # Musí mít stejný počet částí

        params = {}
        match = route_parts.each_with_index.all? do |part, index|
          if part.start_with?(":") # Dynamický parametr
            param_name = part[1..]
            params[param_name.to_sym] = path_parts[index]
            true
          else
            part == path_parts[index] # Musí odpovídat
          end
        end

        return [block, params] if match
      end

      [nil, {}]
    end

    def self.parse_coap_request(data)
      puts "Raw data encoding: #{data.encoding}"
      puts "Raw data bytes: #{data.bytes.inspect}"

      version_type_tkl = data.bytes[0]
      code = data.bytes[1]
      data.bytes[2..3].pack("C*").unpack1("n")
      token_length = version_type_tkl & 0x0F # Token length (poslední 4 bity prvního bytu)
      token = data[4, token_length] || "".b # Token může mít délku 0-8 bajtů

      method = case code
               when 1 then "GET"
               when 2 then "POST"
               when 3 then "PUT"
               when 4 then "DELETE"
               else "UNKNOWN"
               end

      path = extract_uri_path(data.bytes[(4 + token_length)..]).dup
      puts "Parsed path encoding: #{path.encoding}"

      payload_start = data.index("\xFF".b) # Hledáme start payloadu (0xFF)
      payload = payload_start ? data[(payload_start + 1)..].dup.force_encoding("ASCII-8BIT") : nil
      payload.force_encoding("UTF-8") if payload&.valid_encoding?

      puts "Extracted payload encoding: #{payload.encoding}" if payload

      [method, path, token, payload]
    rescue StandardError => e
      puts "Error parsing CoAP message: #{e.message}"
      ["UNKNOWN", "", "".b, nil]
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

    def self.build_coap_response(code, payload, token)
      message_id = rand(0..0xFFFF)

      response_code = case code
                      when 2.05 then 69  # 2.05 Content
                      when 4.04 then 132 # 4.04 Not Found
                      else 160           # Generic response
                      end

      header = [0x60 | (token.bytesize & 0x0F), response_code, (message_id >> 8) & 0xFF, message_id & 0xFF].pack("C*")
      # 0x60 → ACK zpráva (verze 1, typ ACK), + token length bits

      payload_marker = "\xFF".b # Označuje začátek payloadu
      payload_data = payload.to_json.force_encoding("ASCII-8BIT") # Ujistíme se, že je binární

      header + token + payload_marker + payload_data
    end
  end
end
