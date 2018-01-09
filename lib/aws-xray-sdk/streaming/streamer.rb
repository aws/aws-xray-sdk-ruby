module XRay
  # The interface used by the X-Ray recoder to get eligible subsegments
  # to be streamed out from a given segment.
  module Streamer
    def eligible?(segment:)
      raise 'Not implemented'
    end

    def subsegments_to_stream(segment:, emitter:, force: false)
      raise 'Not implemented'
    end

    def stream_threshold=(v)
      raise 'Not implemented'
    end
  end
end
