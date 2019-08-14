module XRay
  # LambdaEmitter extends DefaultEmitter to filter out
  # the subsegments recorded by the AWS Lambda runtime
  # when the function execution is complete.
  class LambdaEmitter < XRay::DefaultEmitter
    def should_send?(entity:)
      entity.name != '127.0.0.1' #Do not send localhost entities. It's the ruby lambda runtime
    end

    def send_entity(entity:)
      return nil unless should_send?(entity: entity)
      super
    end
  end
end
