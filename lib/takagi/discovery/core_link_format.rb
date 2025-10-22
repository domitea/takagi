# frozen_string_literal: true

require 'uri'

module Takagi
  module Discovery
    # Builds CoRE Link Format payloads as defined in RFC 6690.
    class CoreLinkFormat
      CONTENT_FORMAT = 40

      def self.generate(router:, request: nil)
        query = request&.uri&.query
        new(router, query).generate
      end

      def initialize(router, raw_query)
        @router = router
        @query = parse_query(raw_query)
      end

      def generate
        resources = router.link_format_entries
        server_entry = server_link_entry
        resources << server_entry if server_entry
        filtered = filter_resources(resources.reject { |entry| entry.path == '/.well-known/core' })
        filtered.map { |entry| format_entry(entry) }.join(',')
      end

      private

      attr_reader :router, :query

      def parse_query(raw_query)
        return {} if raw_query.nil? || raw_query.empty?

        URI.decode_www_form(raw_query).each_with_object(Hash.new { |h, k| h[k] = [] }) do |(key, value), acc|
          acc[key] << (value || '')
        end
      end

      def filter_resources(resources)
        return resources if query.empty?

        resources.select do |entry|
          query.all? { |key, values| matches_filter?(entry, key, values) }
        end
      end

      def matches_filter?(entry, key, values)
        case key
        when 'rt'
          Array(entry.metadata[:rt]).any? { |rt| values.include?(rt.to_s) }
        when 'if'
          Array(entry.metadata[:if]).any? { |iface| values.include?(iface.to_s) }
        when 'ct'
          values.any? { |val| entry.metadata[:ct].to_i == val.to_i }
        when 'title'
          title = entry.metadata[:title]
          title && values.include?(title.to_s)
        when 'sz'
          size = entry.metadata[:sz]
          size && values.any? { |val| size.to_i == val.to_i }
        when 'obs'
          entry.metadata[:obs]
        when 'href'
          values.any? { |val| entry.path == val }
        else
          false
        end
      end

      def format_entry(entry)
        attributes = link_attributes_for(entry)
        "<#{normalize_path(entry.path)}>#{attributes}"
      end

      def normalize_path(path)
        path == '/' ? path : path
      end

      def link_attributes_for(entry)
        metadata = entry.metadata

        attrs = []
        append_attribute(attrs, 'rt', metadata[:rt]) if metadata[:rt]
        append_attribute(attrs, 'if', metadata[:if]) if metadata[:if]
        append_numeric_attribute(attrs, 'ct', metadata[:ct]) if metadata.key?(:ct)
        append_numeric_attribute(attrs, 'sz', metadata[:sz]) if metadata.key?(:sz)
        append_attribute(attrs, 'title', metadata[:title]) if metadata[:title]
        attrs << ';obs' if metadata[:obs]
        join_attributes(attrs)
      end

      def append_attribute(attrs, name, value)
        return if value.nil?

        if value.is_a?(Array)
          value.each { |single| attrs << %(;#{name}="#{single}") }
        else
          attrs << %(;#{name}="#{value}")
        end
      end

      def append_numeric_attribute(attrs, name, value)
        return if value.nil?

        attrs << %(;#{name}=#{value})
      end

      def join_attributes(attrs)
        attrs.join
      end

      def server_link_entry
        name = Takagi.config.server_name
        return if name.nil? || name.empty?

        Takagi::Router::RouteEntry.new(
          method: 'SERVER',
          path: '/',
          block: nil,
          metadata: {
            rt: 'core.server',
            if: 'takagi.meta',
            ct: Takagi::Router::DEFAULT_CONTENT_FORMAT,
            title: name
          },
          receiver: nil
        )
      end
    end
  end
end
