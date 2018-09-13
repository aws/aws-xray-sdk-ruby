require 'date'
require 'aws-xray-sdk/sampling/sampling_decision'

module XRay
  # Centralized thread-safe reservoir which holds fixed sampling
  # quota for the current instance, borrowed count and TTL.
  class Reservoir
    attr_reader :quota, :ttl

    def initialize
      @quota = nil
      @ttl = nil

      @this_sec = 0
      @taken_this_sec = 0
      @borrowed_this_sec = 0

      @report_interval = 1
      @report_elapsed = 0

      @lock = Mutex.new
    end

    # Decide whether to borrow or take one quota from
    # the reservoir. Return `false` if it can neither
    # borrow nor take. This method is thread-safe.
    def borrow_or_take(now, borrowable)
      @lock.synchronize do
        reset_new_sec(now)
        # Don't borrow if the quota is available and fresh.
        if quota_fresh?(now)
          return SamplingDecision::NOT_SAMPLE if @taken_this_sec >= @quota
          @taken_this_sec += 1
          return SamplingDecision::TAKE
        end

        # Otherwise try to borrow if the quota is not present or expired.
        if borrowable
          return SamplingDecision::NOT_SAMPLE if @borrowed_this_sec >= 1
          @borrowed_this_sec += 1
          return SamplingDecision::BORROW
        end

        # Cannot sample if quota expires and cannot borrow
        SamplingDecision::NOT_SAMPLE
      end
    end

    def load_target_info(quota:, ttl:, interval:)
      @quota = quota unless quota.nil?
      @ttl = ttl.to_i unless ttl.nil?
      @interval = interval / 10 unless interval.nil?
    end

    def time_to_report?
      if @report_elapsed + 1 >= @report_interval
        @report_elapsed = 0
        true
      else
        @report_elapsed += 1
        false
      end
    end

    private

    # Reset the counter if now enters a new one-second window
    def reset_new_sec(now)
      return if now == @this_sec
      @taken_this_sec = 0
      @borrowed_this_sec = 0
      @this_sec = now
    end

    def quota_fresh?(now)
      @quota && @quota >= 0 && @ttl && @ttl >= now
    end
  end
end
