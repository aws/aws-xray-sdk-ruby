require 'aws-xray-sdk/recorder'

module XRay
  class LambdaRecorder < Recorder
    include Logging

    def begin_segment(name, trace_id: nil, parent_id: nil, sampled: nil)
      # no-op
      logger.warn('Cannot create segments inside Lambda function. Returning current segment.')
      return current_segment
    end
    
    def end_segment(end_time: nil)
      # no-op
      logger.warn('Cannot end segment inside Lambda function. Ignored.')
      nil
    end
  end
end
