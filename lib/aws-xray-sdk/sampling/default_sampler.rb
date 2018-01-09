require 'aws-xray-sdk/sampling/sampler'
require 'aws-xray-sdk/sampling/sampling_rule'
require 'aws-xray-sdk/exceptions'

module XRay
  # The default sampler that uses internally defined
  # sampling rule and reservoir models to decide sampling decision.
  # It also uses the default sampling rule.
  # An example definition:
  #   {
  #     version: 1,
  #     rules: [
  #       {
  #         description: 'Player moves.',
  #         service_name: '*',
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
  class DefaultSampler
    include Sampler
    DEFAULT_RULES = {
      version: 1,
      default: {
        fixed_target: 1,
        rate: 0.05
      },
      rules: []
    }.freeze

    def initialize
      load_sampling_rules(DEFAULT_RULES)
    end

    # Return True if the sampler decide to sample based on input
    # information and sampling rules. It will first check if any
    # custom rule should be applied, if not it falls back to the
    # default sampling rule.
    # All arugments are extracted from incoming requests by
    # X-Ray middleware to perform path based sampling.
    def sample_request?(service_name:, url_path:, http_method:)
      # directly fallback to non-path-based if all arguments are nil
      return sample? unless service_name || url_path || http_method
      @custom_rules ||= []
      @custom_rules.each do |c|
        return should_sample?(c) if c.applies?(target_name: service_name, target_path: url_path, target_method: http_method)
      end
      sample?
    end

    # Decides if should sample based on non-path-based rule.
    # Currently only the default rule is not path-based.
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
      if version != 1
        raise InvalidSamplingConfigError, %('Sampling rule version #{version} is not supported.')
      end
      unless v[:default]
        raise InvalidSamplingConfigError, 'A default rule must be provided.'
      end
      @default_rule = SamplingRule.new rule_definition: v[:default], default: true
      @custom_rules = []
      v[:rules].each do |d|
        @custom_rules << SamplingRule.new(rule_definition: d)
      end
    end
  end
end
