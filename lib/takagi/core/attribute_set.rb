# frozen_string_literal: true

module Takagi
  module Core
    # Encapsulates CoRE Link Format attribute handling for a single route.
    class AttributeSet
      CONTENT_FORMATS = {
        'text/plain' => 0,
        'application/link-format' => 40,
        'application/xml' => 41,
        'application/octet-stream' => 42,
        'application/exi' => 47,
        'application/json' => 50,
        'application/cbor' => 60
      }.freeze

      REMOVE = Object.new

      attr_reader :metadata

      def initialize(metadata)
        @metadata = metadata
        @overrides = {}
      end

      def core(&block)
        instance_exec(&block) if block
      end

      def ct(value)
        metadata_override(:ct, normalize_content_format(value))
      end
      alias content_format ct

      def sz(value)
        metadata_override(:sz, value.to_i)
      end

      def title(value)
        metadata_override(:title, value.to_s)
      end

      def obs(value = true)
        metadata_override(:obs, value ? true : REMOVE)
      end
      alias observable obs

      def rt(*values)
        assign_list(:rt, values)
      end

      def interface(*values)
        assign_list(:if, values)
      end
      alias if_ interface

      def attribute(name, value)
        metadata_override(name.to_sym, value.nil? ? REMOVE : value)
      end

      def apply!
        return if @overrides.empty?

        @overrides.each do |key, value|
          if value.equal?(REMOVE)
            metadata.delete(key)
            next
          end

          coerced = if value.is_a?(Array)
                      normalized = value.map(&:to_s)
                      normalized.length == 1 ? normalized.first : normalized
                    else
                      value
                    end
          metadata[key] = coerced
        end

        @overrides.clear
      end

      private

      def assign_list(key, values)
        flattened = values.flatten.compact
        return if flattened.empty?

        overrides = Array(@overrides[key])
        overrides = [] if overrides.empty?

        flattened.each do |value|
          str = value.to_s
          overrides << str unless overrides.include?(str)
        end

        @overrides[key] = overrides
      end

      def metadata_override(key, value)
        @overrides[key] = value
      end

      def normalize_content_format(value)
        case value
        when Integer
          value
        when String
          normalized = value.strip
          return normalized.to_i if normalized.match?(/\A\d+\z/)

          mapped = CONTENT_FORMATS[normalized.downcase]
          return mapped if mapped

          raise ArgumentError, "Unknown content format: #{value}"
        else
          raise ArgumentError, "Unsupported content-format value: #{value.inspect}"
        end
      end
    end
  end
end
