module XRay
  # Stores the enum style sampling decisions for default sampler
  module SamplingDecision
    TAKE = 'take'.freeze
    BORROW = 'borrow'.freeze
    NOT_SAMPLE = 'no'.freeze
  end
end
