module XRay
  # LambdaStreamer extends DefaultStreamer so that subsegments 
  # are sent to the XRay endpoint as they are available.
  class LambdaStreamer < XRay::DefaultStreamer
    def initialize
      @stream_threshold = 1 #Stream every subsegment as it is available
    end
  end
end