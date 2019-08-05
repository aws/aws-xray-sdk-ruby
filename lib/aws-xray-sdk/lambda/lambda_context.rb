require_relative '../model/trace_header'

module XRay
  # LambdaContext extends the default context so that
  # we can provide an appropriate FacadeSegment as the
  # root context for each function invocation.
  class LambdaContext < XRay::DefaultContext
 
    TRACE_ID_ENV_VAR = '_X_AMZN_TRACE_ID'.freeze

    def lambda_trace_id
      ENV[TRACE_ID_ENV_VAR]
    end

    # If the environment trace id changes, create a new facade for that
    # segment and make it the context's current entity
    def check_context
      #Create a new FacadeSegment if the _X_AMZN_TRACE_ID changes.
      return if lambda_trace_id == @current_trace_id

      @current_trace_id = lambda_trace_id
      trace_header = XRay::TraceHeader.from_header_string(header_str: @current_trace_id)
      segment = FacadeSegment.new(trace_id: trace_header.root,
        parent_id: trace_header.parent_id,
        id: trace_header.parent_id,
        name: 'lambda_context',
        sampled: trace_header.sampled == 1
      )
      store_entity(entity: segment)
    end

    def current_entity
      check_context #ensure the FacadeSegment is current whenever the current_entity is retrieved
      super
    end
  end
end
