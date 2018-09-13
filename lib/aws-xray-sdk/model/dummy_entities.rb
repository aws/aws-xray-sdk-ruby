require 'aws-xray-sdk/model/segment'
require 'aws-xray-sdk/model/subsegment'
require 'aws-xray-sdk/model/annotations'
require 'aws-xray-sdk/model/metadata'

module XRay
  # defines common no-op methods for dummy segments/subsegments
  module DummyEntity
    def sampled
      false
    end

    def annotations
      FacadeAnnotations
    end

    def metadata(namespace: :default)
      FacadeMetadata
    end

    def apply_status_code(status:)
      # no-op
    end

    def merge_http_request(request:)
      # no-op
    end

    def merge_http_response(response:)
      # no-op
    end

    def add_exception(exception:, remote: false)
      # no-op
    end

    def aws=(v)
      # no-op
    end

    def sampling_rule_name=(v)
      # no-op
    end

    def to_h
      # no-op
    end

    def to_json
      # no-op
    end
  end

  # A dummy segment is created when ``xray_recorder`` decides to not sample
  # the segment based on sampling decisions.
  # Adding data to a dummy segment becomes a no-op except for
  # subsegments. This is to reduce the memory footprint of the SDK.
  # A dummy segment will not be sent to the X-Ray daemon by the default emitter.
  # Manually create dummy segments is not recommended.
  class DummySegment < Segment
    include DummyEntity
  end

  # A dummy subsegment will be created when ``xray_recorder`` tries
  # to create a subsegment under a not sampled segment. Adding data
  # to a dummy subsegment becomes no-op except for child subsegments.
  # Dummy subsegment will not be sent to the X-Ray daemon by the default emitter.
  # Manually create dummy subsegments is not recommended.
  class DummySubsegment < Subsegment
    include DummyEntity

    def sql=(v)
      # no-op
    end
  end
end
