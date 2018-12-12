require 'aws-xray-sdk/logger'

module XRay
  # The sampling decision and trace ID are added to HTTP requests in
  # tracing headers named ``X-Amzn-Trace-Id``. The first X-Ray-integrated
  # service that the request hits adds a tracing header, which is read
  # by the X-Ray SDK and included in the response.
  class TraceHeader
    include Logging
    attr_accessor :root, :parent_id, :sampled

    # @param [String] root Trace id.
    # @param [String] parent_id The id of the parent segment or subsegment.
    # @param [Integer] sampled 0 means not sampled.
    def initialize(root:, parent_id:, sampled:)
      @root = root
      @parent_id = parent_id
      @sampled = sampled.to_i if sampled
    end

    def self.from_entity(entity:)
      return empty_header if entity.nil?
      root = entity.segment.trace_id
      parent_id = entity.id
      sampled = entity.sampled ? 1 : 0
      new root: root, parent_id: parent_id, sampled: sampled
    end

    def self.from_header_string(header_str:)
      empty_header if header_str.to_s.empty?
      header = header_str.delete(' ').downcase
      tmp = {}
      begin
        fields = header.split(';')
        fields.each do |f|
          pair = f.split('=')
          tmp[pair[0].to_sym] = pair[1]
        end
        new root: tmp[:root], parent_id: tmp[:parent], sampled: tmp[:sampled]
      rescue StandardError
        logger.warn %(Invalid trace header #{header}. Ignored.)
        empty_header
      end
    end

    # @return [String] The header string of the root object
    def root_string
	%(Root=#{root})
    end

    # @return [String] The heading string constructed based on this header object.
    def header_string
      return '' unless root
      if !parent_id
        %(#{root_string};Sampled=#{sampled})
      elsif !sampled
        %(#{root_string};Parent=#{parent_id})
      else
        %(#{root_string};Parent=#{parent_id};Sampled=#{sampled})
      end
    end

    def self.empty_header
      new root: nil, parent_id: nil, sampled: nil
    end
  end
end
