module XRay
  # Keeps track of the number of sampled segments within
  # a single second in the local process. This class is
  # implemented to be thread-safe to achieve accurate sampling.
  class LocalReservoir
    # @param [Integer] traces_per_sec The number of guranteed sampled
    #   segments per second.
    def initialize(traces_per_sec: 0)
      @traces_per_sec = traces_per_sec
      @used_this_sec = 0
      @this_sec = Time.now.to_i
      @lock = Mutex.new
    end

    # Returns `true` if there are quota left within the
    # current second, otherwise returns `false`.
    def take
      # nothing to provide if reserved is set to 0
      return false if @traces_per_sec.zero?
      @lock.synchronize do
        now = Time.now.to_i
        # refresh time frame
        if now != @this_sec
          @used_this_sec = 0
          @this_sec = now
        end
        # return false if reserved item ran out
        return false unless @used_this_sec < @traces_per_sec
        # otherwise increment used counter and return true
        @used_this_sec += 1
        return true
      end
    end
  end
end
