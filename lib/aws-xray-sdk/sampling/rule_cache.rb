require 'aws-xray-sdk/logger'

module XRay
  # Cache sampling rules and quota retrieved by `TargetPoller`
  # and `RulePoller`. It will not return anything if it expires.
  class RuleCache
    include Logging
    attr_accessor :last_updated
    @@TTL = 60 * 60 # 1 hour

    def initialize
      @rules = []
      @last_updated = nil
      @lock = Mutex.new
    end

    def get_matched_rule(sampling_req, now: Time.now.to_i)
      return nil if expired?(now)
      matched = nil
      rules.each do |rule|
        matched = rule if matched.nil? && rule.applies?(sampling_req)
        matched = rule if matched.nil? && rule.default?
      end
      matched
    end

    def load_rules(new_rules)
      @lock.synchronize do
        # Simply assign rules and sort if cache is empty
        if @rules.empty?
          @rules = new_rules
          return sort_rules
        end

        # otherwise we need to merge new rules and current rules
        curr_rules = {}
        @rules.each do |rule|
          curr_rules[rule.name] = rule
        end
        # Update the rules in the cache
        @rules = new_rules
        # Transfer state information
        @rules.each do |rule|
          curr_rule = curr_rules[rule.name]
          rule.merge(curr_rule) unless curr_rule.nil?
        end
        sort_rules
      end
    end

    def load_targets(targets_h)
      @lock.synchronize do
        @rules.each do |rule|
          target = targets_h[rule.name]
          next if target.nil?
          rule.rate = target.fixed_rate
          rule.reservoir.load_target_info(
            quota: target.reservoir_quota,
            ttl: target.reservoir_quota_ttl,
            interval: target.interval
          )
        end
      end
    end

    def rules
      @lock.synchronize do
        @rules
      end
    end

    private

    # The cache should maintain the order of the rules based on
    # priority. If priority is the same we sort name by alphabet
    # as rule name is unique.
    def sort_rules
      @rules.sort_by! { |rule| [rule.priority, rule.name] }      
    end

    def expired?(now)
      # The cache is treated as expired if it is never loaded.
      @last_updated.nil? || now > @last_updated + @@TTL
    end
  end
end
