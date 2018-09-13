require 'aws-xray-sdk/model/entity'

module XRay
  # The compute resources running your application logic send data
  # about their work as segments. A segment provides the resource's name,
  # details about the request, and details about the work done.
  class Segment
    include Entity
    attr_accessor :ref_counter, :subsegment_size, :origin,
                  :user, :service

    # @param [String] trace_id Manually crafted trace id.
    # @param [String] name Must be specified either on object creation or
    #   on environment variable `AWS_TRACING_NAME`. The latter has higher precedence.
    # @param [String] parent_id ID of the segment/subsegment representing the upstream caller.
    def initialize(trace_id: nil, name: nil, parent_id: nil)
      @trace_id = trace_id
      @name = ENV['AWS_TRACING_NAME'] || name
      @parent_id = parent_id
      @start_time = Time.now.to_f
      @ref_counter = 0
      @subsegment_size = 0
      @sampled = true
    end

    def trace_id
      @trace_id ||= begin
        %[1-#{Time.now.to_i.to_s(16)}-#{SecureRandom.hex(12)}]
      end
    end

    def add_subsegment(subsegment:)
      super subsegment: subsegment
      @ref_counter += 1
      @subsegment_size += 1
    end

    def remove_subsegment(subsegment:)
      super subsegment: subsegment
      @subsegment_size = subsegment_size - subsegment.all_children_count - 1
    end

    def sampling_rule_name=(v)
      @aws ||= {}
      @aws[:xray] ||= {}
      @aws[:xray][:sampling_rule_name] = v
    end

    def decrement_ref_counter
      @ref_counter -= 1
    end

    def ready_to_send?
      closed? && ref_counter.zero?
    end

    def to_h
      h = super
      h[:trace_id] = trace_id
      h[:origin] = origin if origin
      h[:parent_id] = @parent_id if @parent_id
      h[:user] = user if user
      h[:service] = service if service
      h
    end

    def segment
      self
    end
  end
end
