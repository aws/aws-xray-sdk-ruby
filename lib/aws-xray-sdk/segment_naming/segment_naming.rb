module XRay
  # The interface that provides the segment name
  # based on host name, pattern and the fallback name.
  module SegmentNaming
    attr_accessor :fallback, :pattern
    def provide_name(host:)
      raise 'Not implemented'
    end
  end
end
