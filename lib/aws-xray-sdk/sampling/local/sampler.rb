require 'aws-xray-sdk/sampling/sampler'
require 'aws-xray-sdk/sampling/local/sampling_rule'
require 'aws-xray-sdk/exceptions'

module XRay
  # The local sampler that uses locally defined
  # sampling rule and reservoir models to decide sampling decision.
  # It also uses the default sampling rule.
  # An example definition:
  #   {
  #     version: 2,
  #     rules: [
  #       {
  #         description: 'Player moves.',
  #         host: '*',
  #         http_method: '*',
  #         url_path: '/api/move/*',
  #         fixed_target: 0,
  #         rate: 0.05
  #       }
  #     ],
  #     default: {
  #       fixed_target: 1,
  #       rate: 0.1
  #     }
  #   }
  # This example defines one custom rule and a default rule.
  # The custom rule applies a five-percent sampling rate with no minimum
  # number of requests to trace for paths under /api/move/. The default
  # rule traces the first request each second and 10 percent of additional requests.
  # The SDK applies custom rules in the order in which they are defined.
  # If a request matches multiple custom rules, the SDK applies only the first rule.
  class LocalSampler
    include Sampler
    DEFAULT_RULES = {
      version: 2,
      default: {
        fixed_target: 1,
        rate: 0.05
      },
      rules: []
    }.freeze

    SUPPORTED_VERSION = [1, 2].freeze

    def initialize
      load_sampling_rules(DEFAULT_RULES)
    end

    # Return True if the sampler decide to sample based on input
    # information and sampling rules. It will first check if any
    # custom rule should be applied, if not it falls back to the
    # default sampling rule.
    # All arugments are extracted from incoming requests by
    # X-Ray middleware to perform path based sampling.
    def sample_request?(sampling_req)
      sample = sample?
      return sample if sampling_req.nil? || sampling_req.empty?
      @custom_rules ||= []
      @custom_rules.each do |c|
        return should_sample?(c) if c.applies?(sampling_req)
      end
      # use previously made decision based on default rule
      # if no path-based rule has been matched
      sample
    end

    # Decides if should sample based on non-path-based rule.
    # Currently only the default rule is non-path-based.
    def sample?
      should_sample?(@default_rule)
    end

    # @param [Hash] v The sampling rules definition.
    def sampling_rules=(v)
      load_sampling_rules(v)
    end

    # @return [Array] An array of [SamplingRule]
    def sampling_rules
      all_rules = []
      all_rules << @default_rule
      all_rules << @custom_rules unless @custom_rules.empty?
      all_rules
    end

    private

    def should_sample?(rule)
      return true if rule.reservoir.take
      Random.rand <= rule.rate
    end

    def load_sampling_rules(v)
      version = v[:version]
      unless SUPPORTED_VERSION.include?(version)
        raise InvalidSamplingConfigError, %('Sampling rule version #{version} is not supported.')
      end
      unless v[:default]
        raise InvalidSamplingConfigError, 'A default rule must be provided.'
      end
      @default_rule = LocalSamplingRule.new rule_definition: v[:default], default: true
      @custom_rules = []
      v[:rules].each do |d|
        d[:host] = d[:service_name] if version == 1
        @custom_rules << LocalSamplingRule.new(rule_definition: d)
      end
    end
  end
end
