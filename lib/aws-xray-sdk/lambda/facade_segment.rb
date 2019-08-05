module XRay
  class FacadeSegment < XRay::Segment

    class ImmutableEmptyCollection
      def [](key)
        nil
      end
  
      def []=(k, v)
        raise UnsupportedOperationError
      end
  
      def update(h)
        raise UnsupportedOperationError
      end
  
      def to_h
        {}
      end
    end


    def initialize(trace_id: nil, name: nil, parent_id: nil, id: nil, sampled: true)
      super(trace_id: trace_id, name: name, parent_id: parent_id)
      @id = id
      @sampled = sampled
      @empty_collection = ImmutableEmptyCollection.new
    end

    def ready_to_send?
      false #never send this facade. AWS Lambda has already created a Segment with these ids
    end

    #
    #Methods from Entity that are not supported
    #
    def close(end_time: nil)
      raise UnsupportedOperationError
    end
    def apply_status_code(status:)
      raise UnsupportedOperationError
    end
    def merge_http_request(request:)
      raise UnsupportedOperationError
    end
    def merge_http_response(response:)
      raise UnsupportedOperationError
    end
    def add_exception(exception:, remote: false)
      raise UnsupportedOperationError
    end

    #
    # Mutation accessors from Entity that are not supported
    #
    def parent=(value)
      raise UnsupportedOperationError
    end
    def throttle=(value)
      raise UnsupportedOperationError
    end
    def error=(value)
      raise UnsupportedOperationError
    end
    def fault=(value)
      raise UnsupportedOperationError
    end
    def sampled=(value)
      raise UnsupportedOperationError
    end
    def aws=(value)
      raise UnsupportedOperationError
    end
    def start_time=(value)
      raise UnsupportedOperationError
    end
    def end_time=(value)
      raise UnsupportedOperationError
    end

    #
    # Mutation accessors from Segment that are not supported
    #
    def origin=(value)
      raise UnsupportedOperationError
    end
    def user=(value)
      raise UnsupportedOperationError
    end
    def service=(value)
      raise UnsupportedOperationError
    end
    
    #
    # Annotations are read only
    #
    def annotations
      @empty_collection
    end

    #
    # Metadata is read only
    #
    def metadata(namespace: :default)
      @empty_collection
    end

  end
end
