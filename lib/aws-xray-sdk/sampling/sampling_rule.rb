require 'aws-xray-sdk/exceptions'
require 'aws-xray-sdk/sampling/reservoir'
require 'aws-xray-sdk/search_pattern'

module XRay
  # One SamplingRule object represents one rule defined from the rules hash definition.
  # It can be either a custom rule or the default rule.
  class SamplingRule
    attr_reader :fixed_target, :rate, :service_name,
                :method, :path, :reservoir, :default

    # @param [Hash] rule_definition Hash that defines a single rule.
    # @param default A boolean flag indicates if this rule is the default rule.
    def initialize(rule_definition:, default: false)
      @fixed_target = rule_definition[:fixed_target]
      @rate = rule_definition[:rate]

      @service_name = rule_definition[:service_name]
      @method = rule_definition[:http_method]
      @path = rule_definition[:url_path]

      @default = default
      validate
      @reservoir = Reservoir.new traces_per_sec: @fixed_target
    end

    # Determines whether or not this sampling rule applies to
    # the incoming request based on some of the request's parameters.
    # Any None parameters provided will be considered an implicit match.
    def applies?(target_name:, target_path:, target_method:)
      name_match   = !target_name   || SearchPattern.wildcard_match?(pattern: @service_name, text: target_name)
      path_match   = !target_path   || SearchPattern.wildcard_match?(pattern: @path, text: target_path)
      method_match = !target_method || SearchPattern.wildcard_match?(pattern: @method, text: target_method)
      name_match && path_match && method_match
    end

    private

    def validate
      if @fixed_target < 0 || @rate < 0
        raise InvalidSamplingConfigError, 'All rules must have non-negative values for fixed_target and rate.'
      end

      if @default
        # validate default rule
        if @service_name || @method || @path
          raise InvalidSamplingConfigError, 'The default rule must not specify values for url_path, service_name, or http_method.'
        end
      else
        # validate custom rule
        unless @service_name && @method && @path
          raise InvalidSamplingConfigError, 'All non-default rules must have values for url_path, service_name, and http_method.'
        end
      end
    end
  end
end
