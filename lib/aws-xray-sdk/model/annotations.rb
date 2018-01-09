require 'aws-xray-sdk/logger'
require 'aws-xray-sdk/exceptions'

module XRay
  # Annotations are simple key-value pairs that are indexed for use with filter expressions.
  # Use annotations to record data that you want to use to group traces in the console,
  # or when calling the GetTraceSummaries API.
  class Annotations
    include Logging

    def initialize(entity)
      @entity = entity
      @data = {}
    end

    def [](key)
      @data[key]
    end

    # @param [Symbol] k Only characters in `A-Za-z0-9_` are supported.
    # @param v Only `Numeric`, `String` true/false is supported.
    def []=(k, v)
      raise EntityClosedError if @entity.closed?
      if key_supported?(k) && value_supported?(v)
        @data[k] = v
      else
        logger.warn %(Dropping annotation with key #{k} due to invalid characters.)
      end
    end

    # @param [Hash] h Update annotations with a single input hash.
    def update(h)
      raise EntityClosedError if @entity.closed?
      filtered = filter_annotations(h)
      @data.merge!(filtered)
    end

    def to_h
      sanitize_values(@data)
    end

    private

    def filter_annotations(h)
      h.delete_if do |k, v|
        drop = !key_supported?(k) || !value_supported?(v)
        logger.warn %(Dropping annotation with key #{k} due to invalid characters.) if drop
        drop
      end
    end

    def sanitize_values(h)
      h.each_pair do |k, v|
        if v.is_a?(Float)
          h[k] = v.to_s if v.nan? || v.infinite? == 1 || v.infinite? == -1
        end
      end
    end

    def key_supported?(k)
      k.match(/[A-Za-z0-9_]+/)
    end

    def value_supported?(v)
      case v
      when Numeric
        true
      when true, false
        true
      else
        v.is_a?(String)
      end
    end
  end

  # Singleton facade annotations class doing no-op for performance
  # in case of not sampled X-Ray entities.
  module FacadeAnnotations
    class << self
      def [](key)
        # no-op
      end

      def []=(k, v)
        # no-op
      end

      def update(h)
        # no-op
      end

      def to_h
        # no-op
      end
    end
  end
end
