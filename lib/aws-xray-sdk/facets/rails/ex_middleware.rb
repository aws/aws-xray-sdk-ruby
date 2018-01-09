require 'aws-xray-sdk'

module XRay
  module Rails
    # Middleware for capturing unhandled exceptions from views/controller.
    # To properly capture exceptions this middleware needs to be placed
    # after the default exception handling middleware. Otherwise they will
    # be swallowed.
    class ExceptionMiddleware
      def initialize(app, recorder: nil)
        @app = app
        @recorder = recorder || XRay.recorder
      end

      def call(env)
        @app.call(env)
      rescue Exception => e
        segment = @recorder.current_segment
        segment.add_exception exception: e if segment
        raise e
      end
    end
  end
end
