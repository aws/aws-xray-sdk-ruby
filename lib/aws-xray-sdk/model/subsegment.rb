require 'aws-xray-sdk/model/entity'

module XRay
  # The work done in a single segment can be broke down into subsegments.
  # Subsegments provide more granular timing information and details about
  # downstream calls that your application made to fulfill the original request.
  # A subsegment can contain additional details about a call to an AWS service,
  # an external HTTP API, or an SQL database.
  class Subsegment
    include Entity

    attr_reader :segment
    attr_accessor :sql

    # @param [String] name The subsegment name.
    # @param [Segment] segment The root parent segment. This segment
    #   may not be its direct parent.
    # @param [String] namespace Currently supported namespaces are
    #   'remote', 'aws', 'local'.
    def initialize(name:, segment:, namespace: 'local')
      @name = name
      @segment = segment
      @namespace = namespace
      @start_time = Time.now.to_f
      @sampled = true
    end

    def add_subsegment(subsegment:)
      super subsegment: subsegment
      segment.ref_counter += 1
      segment.subsegment_size += 1
    end

    def remove_subsegment(subsegment:)
      super subsegment: subsegment
      cur = segment.subsegment_size
      segment.subsegment_size = cur - subsegment.all_children_count - 1
    end

    def close(end_time: nil)
      super end_time: end_time
      segment.decrement_ref_counter
    end

    def sql
      @sql ||= {}
    end

    # Returns the number of its direct and indirect children.
    # This is useful when we remove the reference to a subsegment
    # and need to keep remaining subsegment size accurate.
    def all_children_count
      size = subsegments.count
      subsegments.each { |v| size += v.all_children_count }
      size
    end

    def to_h
      h = super
      h[:trace_id] = segment.trace_id
      h[:sql] = sql unless sql.empty?
      h[:type] = 'subsegment'
      h[:namespace] = namespace if namespace
      h
    end
  end
end
