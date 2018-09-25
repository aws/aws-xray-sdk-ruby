require 'aws-xray-sdk/logger'
require 'aws-xray-sdk/sampling/connector'
require 'aws-xray-sdk/sampling/rule_poller'

module XRay
  # The poller to report the current statistics of all
  # sampling rules and retrieve the new allocated
  # sampling quota and TTL from X-Ray service. It also
  # controls the rule poller.
  class LeadPoller
    include Logging
    attr_reader :connector
    @@interval = 10 # working frequency of the lead poller
    @@rule_interval = 5 * 60 # 5 minutes on polling rules

    def initialize(cache)
      @cache = cache
      @connector = ServiceConnector.new
      @rule_poller = RulePoller.new cache: @cache, connector: @connector
      @rule_poller_elapsed = 0
    end

    def start
      @rule_poller.run
      Thread.new { worker }
    end

    def worker
      loop do
        sleep_time = @@interval + rand
        sleep sleep_time
        @rule_poller_elapsed += sleep_time
        refresh_cache
        if @rule_poller_elapsed >= @@rule_interval
          @rule_poller.run
          @rule_poller_elapsed = 0
        end
      end
    end

    private

    def refresh_cache
      candidates = get_candidates(@cache.rules)
      if candidates.empty?
        logger.debug %(No X-Ray sampling rules to report statistics. Skipping.)
        return
      end

      result = @connector.fetch_sampling_targets(candidates)
      targets = {}
      result[:documents].each { |doc| targets[doc.rule_name] = doc }
      @cache.load_targets(targets)

      return unless @cache.last_updated && result[:last_modified].to_i > @cache.last_updated
      logger.info 'Performing out-of-band sampling rule polling to fetch updated rules.'
      @rule_poller.run
      @rule_poller_elapsed = 0
    rescue StandardError => e
      logger.warn %(failed to fetch X-Ray sampling targets due to #{e.message})
    end

    # Don't report a rule statistics if any of the conditions is met:
    # 1. The report time hasn't come(some rules might have larger report intervals).
    # 2. The rule is never matched.
    def get_candidates(rules)
      candidates = []
      rules.each { |rule| candidates << rule if rule.ever_matched? && rule.time_to_report? }
      candidates
    end
  end
end
