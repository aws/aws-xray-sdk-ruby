module XRay
  # LambdaEmitter extends DefaultEmitter to filter out
  # the subsegments recorded by the AWS Lambda runtime
  # when the function execution is complete.
  class LambdaEmitter < XRay::DefaultEmitter
    def send_entity(entity:)
      return nil if entity.name == '127.0.0.1' #Do not send localhost entities. It's the ruby lambda runtime
      super
    end
  end
end
