require 'aws-xray-sdk/configuration'
require 'aws-xray-sdk/exceptions'
require 'aws-xray-sdk/model/segment'
require 'aws-xray-sdk/model/subsegment'
require 'aws-xray-sdk/model/dummy_entities'
require 'aws-xray-sdk/model/annotations'
require 'aws-xray-sdk/model/metadata'
require 'aws-xray-sdk/version'

module XRay
  # A global AWS X-Ray recorder that will begin/end segments/subsegments
  # and send them to the X-Ray daemon. It is also responsible for managing
  # context.
  class Recorder
    attr_reader :config, :origin

    def initialize(user_config: nil)
      @config = Configuration.new
      @config.configure(user_config) unless user_config.nil?
      @origin = nil
    end

    # Begin a segment for the current context. The recorder
    # only keeps one segment at a time. Create a second one without
    # closing existing one will overwrite the existing one.
    # @return [Segment] thew newly created segment.
    def begin_segment(name, trace_id: nil, parent_id: nil, sampled: nil)
      seg_name = name || config.name
      raise SegmentNameMissingError if seg_name.to_s.empty?

      # sampling decision comes from outside has higher precedence.
      sample = sampled.nil? ? config.sample? : sampled
      if sample
        segment = Segment.new name: seg_name, trace_id: trace_id, parent_id: parent_id
        populate_runtime_context(segment, sample)
      else
        segment = DummySegment.new name: seg_name, trace_id: trace_id, parent_id: parent_id
      end
      context.store_entity entity: segment
      segment
    end

    # @return [Segment] the active segment tied to the current context.
    #   If the current context is under a subsegment, it returns its parent segment.
    def current_segment
      entity = current_entity
      entity.segment if entity
    end

    # End the current segment and send it to X-Ray daemon if it is ready.
    def end_segment(end_time: nil)
      segment = current_segment
      return unless segment
      segment.close end_time: end_time
      context.clear!
      emitter.send_entity entity: segment if segment.ready_to_send?
    end

    # Begin a new subsegment and add it to be the child of the current active
    # subsegment or segment. Also tie the new created subsegment to the current context.
    # Its sampling decision will follow its parent.
    # @return [Subsegment] the newly created subsegment. It could be `nil` if no active entity
    #   can be found and `context_missing` is set to `LOG_ERROR`.
    def begin_subsegment(name, namespace: nil, segment: nil)
      entity = segment || current_entity
      return unless entity
      if entity.sampled
        subsegment = Subsegment.new name: name, segment: entity.segment, namespace: namespace
      else
        subsegment = DummySubsegment.new name: name, segment: entity.segment
      end
      # attach the new created subsegment under the current active entity
      entity.add_subsegment subsegment: subsegment
      # associate the new subsegment to the current context
      context.store_entity entity: subsegment
      subsegment
    end

    # @return [Subsegment] the active subsegment tied to the current context.
    #   Returns nil if the current context has no associated subsegment.
    def current_subsegment
      entity = context.current_entity
      entity.is_a?(Subsegment) ? entity : nil
    end

    # End the current active subsegment. It also send the entire segment if
    # this subsegment is the last one open or stream out subsegments of its
    # parent segment if the stream threshold is breached.
    def end_subsegment(end_time: nil)
      entity = current_entity
      return unless entity.is_a?(Subsegment)
      entity.close end_time: end_time
      # update current context
      if entity.parent.closed?
        context.clear!
      else
        context.store_entity entity: entity.parent
      end
      # check if the entire segment can be send.
      # If not, stream subsegments when threshold is reached.
      segment = entity.segment
      if segment.ready_to_send?
        emitter.send_entity entity: segment
      elsif streamer.eligible? segment: segment
        streamer.stream_subsegments root: segment, emitter: emitter
      end
    end

    # Record the passed block as a subsegment.
    # If `context_missing` is set to `LOG_ERROR` and no active entity can be found,
    # the passed block will be executed as normal but it will not be recorded.
    def capture(name, namespace: nil, segment: nil)
      subsegment = begin_subsegment name, namespace: namespace, segment: segment
      # prevent passed block from failing in case of context missing with log error
      if subsegment.nil?
        segment = DummySegment.new name: name
        subsegment = DummySubsegment.new name: name, segment: segment
      end

      begin
        yield subsegment
      rescue Exception => e
        subsegment.add_exception exception: e
        raise e
      ensure
        end_subsegment
      end
    end

    # Returns current segment or subsegment that associated to the current context.
    # This is a proxy method to Context class current_entity.
    def current_entity
      context.current_entity
    end

    def inject_context(entity, target_ctx: nil)
      context.inject_context entity, target_ctx: target_ctx
      return unless block_given?
      yield
      context.clear!
    end

    def clear_context
      context.clear!
    end

    def sampled?
      entity = current_entity
      if block_given?
        yield if entity && entity.sampled
      else
        entity && entity.sampled
      end
    end

    # A proxy method to get the annotations from the current active entity.
    def annotations
      entity = current_entity
      if entity
        entity.annotations
      else
        FacadeAnnotations
      end
    end

    # A proxy method to get the metadata under provided namespace
    # from the current active entity.
    def metadata(namespace: :default)
      entity = current_entity
      if entity
        entity.metadata(namespace: namespace)
      else
        FacadeMetadata
      end
    end

    # A proxy method to XRay::Configuration.configure
    def configure(user_config)
      config.configure(user_config)
    end

    def context
      config.context
    end

    def sampler
      config.sampler
    end

    def emitter
      config.emitter
    end

    def streamer
      config.streamer
    end

    def segment_naming
      config.segment_naming
    end

    def sampling_enabled?
      config.sampling
    end

    private_class_method

    def populate_runtime_context(segment, sample)
      @aws ||= begin
        aws = {}
        config.plugins.each do |p|
          meta = p.aws
          if meta.is_a?(Hash) && !meta.empty?
            aws.merge! meta
            @origin = p::ORIGIN
          end
        end
        xray_meta = { xray:
          {
            sdk_version: XRay::VERSION,
            sdk: 'X-Ray for Ruby'
          }
        }
        aws.merge! xray_meta
      end

      @service ||= {
        runtime: RUBY_ENGINE,
        runtime_version: RUBY_VERSION
      }

      segment.aws = @aws
      segment.service = @service
      segment.origin = @origin
      segment.sampling_rule_name = sample if sample.is_a?(String)
    end
  end
end
