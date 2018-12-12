require 'aws-xray-sdk/model/trace_header'

module XRay
  module Facets
    # Hepler functions shared for all external frameworks/libraries
    # like make sampling decisions from incoming http requests etc.
    module Helper
      TRACE_HEADER = 'X-Amzn-Trace-Id'.freeze
      TRACE_HEADER_PROXY = 'HTTP_X_AMZN_TRACE_ID'.freeze

      # Construct a `TraceHeader` object from headers
      # of the incoming request. This method should always return
      # a `TraceHeader` object regardless of tracing header's presence
      # in the incoming request.
      # @param [Hash] headers Hash that contains X-Ray trace header key.
      # @return [TraceHeader] The new constructed trace header object.
      def construct_header(headers:)
        if v = headers[TRACE_HEADER_PROXY] || headers[TRACE_HEADER]
          TraceHeader.from_header_string header_str: v
        else
          TraceHeader.empty_header
        end
      end

      # The sampling decision coming from `trace_header` always has
      # the highest precedence. If the `trace_header` doesn't contain
      # sampling decision then it checks if sampling is enabled or not
      # in the recorder. If not enbaled it returns 'true'. Otherwise it uses
      # sampling rules to decide.
      def should_sample?(header_obj:, recorder:, sampling_req:, **args)
        # check outside decision
        if i = header_obj.sampled
          !i.zero?
        # check sampling rules
        elsif recorder.sampling_enabled?
          recorder.sampler.sample_request?(sampling_req)
        # sample if no reason not to
        else
          true
        end
      end

      # Prepares a X-Ray header string based on the provided Segment/Subsegment.
      def prep_header_str(entity:)
        TraceHeader.from_entity(entity: entity).header_string
      end
    end
  end
end
