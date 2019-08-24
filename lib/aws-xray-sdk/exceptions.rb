module XRay
  # All custom exception thrown by the SDK should subclass AwsXRayError.
  class AwsXRaySdkError < ::StandardError; end

  class EntityClosedError < AwsXRaySdkError
    def initialize
      super('Segment or subsegment already ended.')
    end
  end

  class ContextMissingError < AwsXRaySdkError
    def initialize
      super('Can not find any active segment or subsegment.')
    end
  end

  class SegmentNameMissingError < AwsXRaySdkError
  end

  class InvalidDaemonAddressError < AwsXRaySdkError
  end

  class InvalidSamplingConfigError < AwsXRaySdkError
  end

  class InvalidConfigurationError < AwsXRaySdkError
  end

  class UnsupportedPatchingTargetError < AwsXRaySdkError
  end

  class UnsupportedOperationError < AwsXRaySdkError
  end
end
