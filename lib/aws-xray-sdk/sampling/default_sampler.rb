require 'aws-xray-sdk/logger'
require 'aws-xray-sdk/sampling/local/sampler'
require 'aws-xray-sdk/sampling/lead_poller'
require 'aws-xray-sdk/sampling/rule_cache'
require 'aws-xray-sdk/sampling/sampler'
require 'aws-xray-sdk/sampling/sampling_rule'
require 'aws-xray-sdk/sampling/sampling_decision'

module XRay
  # Making sampling decisions based on service sampling rules defined
  # by X-Ray control plane APIs. It will fall back to local sampling rules
  # if service sampling rules are not available or expired.
  class DefaultSampler
    include Sampler
    include Logging
    attr_reader :cache, :local_sampler, :poller
    attr_accessor :origin

    def initialize
      @local_sampler = LocalSampler.new
      @cache = RuleCache.new
      @poller = LeadPoller.new(@cache)

      @started = false
      @origin = nil
      @lock = Mutex.new
    end

    # Start background threads to poll sampling rules
    def start
      @lock.synchronize do
        unless @started
          @poller.start
          @started = true
        end
      end
    end

    # Return the rule name if it decides to sample based on
    # a service sampling rule matching. If there is no match
    # it will fallback to local defined sampling rules.
    def sample_request?(sampling_req)
      start unless @started
      now = Time.now.to_i
      if sampling_req.nil?
        sampling_req = { service_type: @origin } if @origin
      elsif !sampling_req.key?(:service_type)
        sampling_req[:service_type] = @origin if @origin
      end

      matched_rule = @cache.get_matched_rule(sampling_req, now: now)
      if !matched_rule.nil?
        logger.debug %(Rule #{matched_rule.name} is selected to make a sampling decision.')
        process_matched_rule(matched_rule, now)
      else
        logger.warn %(No effective centralized sampling rule match. Fallback to local rules.)
        @local_sampler.sample_request?(sampling_req)
      end
    end

    def sample?
      sample_request? nil
    end

    # @param [Hash] v Local sampling rules definition.
    # This configuration has lower priority than service
    # sampling rules and only has effect when those rules
    # are not available or expired.
    def sampling_rules=(v)
      @local_sampler.sampling_rules = v
    end

    def daemon_config=(v)
      @poller.connector.daemon_config = v
    end

    private

    def process_matched_rule(rule, now)
      # As long as a rule is matched we increment request counter.
      rule.increment_request_count
      reservoir = rule.reservoir
      sample = true
      # We check if we can borrow or take from reservoir first.
      decision = reservoir.borrow_or_take(now, rule.borrowable?)
      if decision == SamplingDecision::BORROW
        rule.increment_borrow_count
      elsif decision == SamplingDecision::TAKE
        rule.increment_sampled_count
        # Otherwise we compute based on fixed rate of this sampling rule.
      elsif rand <= rule.rate
        rule.increment_sampled_count
      else
        sample = false
      end
      sample ? rule.name : false
    end
  end
end
