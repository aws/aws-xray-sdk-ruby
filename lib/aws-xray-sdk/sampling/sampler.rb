module XRay
  # The sampler interface that calculates if a segment
  # should be sampled or not upon creation based on the
  # sampling rules it holds. It doesn't respect sampling decision
  # from upstream.
  module Sampler
    # Decides if a segment should be sampled for an incoming request.
    # Used in case of middleware.
    def sample_request?(sampling_req:)
      raise 'Not implemented'
    end

    # Sample purely based on cached sampling rules without
    # any incoming rules matching information.
    def sample?
      raise 'Not implemented'
    end

    def sampling_rules=(v)
      raise 'Not implemented'
    end

    def sampling_rules
      raise 'Not implemented'
    end
  end
end
