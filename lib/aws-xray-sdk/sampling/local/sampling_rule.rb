require 'aws-xray-sdk/exceptions'
require 'aws-xray-sdk/sampling/local/reservoir'
require 'aws-xray-sdk/search_pattern'

module XRay
  # One SamplingRule object represents one rule defined from the rules hash definition.
  # It can be either a custom rule or the default rule.
  class LocalSamplingRule
    attr_reader :fixed_target, :rate, :host,
                :method, :path, :reservoir, :default

    # @param [Hash] rule_definition Hash that defines a single rule.
    # @param default A boolean flag indicates if this rule is the default rule.
    def initialize(rule_definition:, default: false)
      @fixed_target = rule_definition[:fixed_target]
      @rate = rule_definition[:rate]

      @host = rule_definition[:host]
      @method = rule_definition[:http_method]
      @path = rule_definition[:url_path]

      @default = default
      validate
      @reservoir = LocalReservoir.new traces_per_sec: @fixed_target
    end

    # Determines whether or not this sampling rule applies to
    # the incoming request based on some of the request's parameters.
    # Any None parameters provided will be considered an implicit match.
    def applies?(sampling_req)
      return false if sampling_req.nil? || sampling_req.empty?

      host = sampling_req[:host]
      url_path = sampling_req[:url_path]
      http_method = sampling_req[:http_method]

      host_match = !host || SearchPattern.wildcard_match?(pattern: @host, text: host)
      path_match = !url_path || SearchPattern.wildcard_match?(pattern: @path, text: url_path)
      method_match = !http_method || SearchPattern.wildcard_match?(pattern: @method, text: http_method)
      host_match && path_match && method_match
    end

    private

    def validate
      if @fixed_target < 0 || @rate < 0
        raise InvalidSamplingConfigError, 'All rules must have non-negative values for fixed_target and rate.'
      end

      if @default
        # validate default rule
        if @host || @method || @path
          raise InvalidSamplingConfigError, 'The default rule must not specify values for url_path, service_name, or http_method.'
        end
      else
        # validate custom rule
        unless @host && @method && @path
          raise InvalidSamplingConfigError, 'All non-default rules must have values for url_path, service_name, and http_method.'
        end
      end
    end
  end
end
