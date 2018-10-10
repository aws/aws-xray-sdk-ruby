require 'aws-xray-sdk/logger'

module XRay
  # Polls sampling rules from X-Ray service
  class RulePoller
    include Logging
    attr_reader :cache, :connector

    def initialize(cache:, connector:)
      @cache = cache
      @connector = connector
    end

    def run
      @worker ||= begin 
        Thread.new { poll }
      end
      @worker.run
    end

    private

    def poll
      loop do
        refresh_cache
        Thread.stop
      end
    end

    def refresh_cache
      now = Time.now.to_i
      rules = @connector.fetch_sampling_rules
      unless rules.nil? || rules.empty?
        @cache.load_rules(rules)
        @cache.last_updated = now
      end
    rescue StandardError => e
      logger.warn %(failed to fetch X-Ray sampling rules due to #{e.message})
    end
  end
end
