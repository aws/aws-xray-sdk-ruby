module XRay
  class FacadeSegment < XRay::Segment
    def initialize(trace_id: nil, name: nil, parent_id: nil, id: nil, sampled: true)
      super(trace_id: trace_id, name: name, parent_id: parent_id)
      @id = id
      @sampled = sampled
    end

    def ready_to_send?
      false #never send this facade. AWS Lambda has already created a Segment with these ids
    end
  end
end