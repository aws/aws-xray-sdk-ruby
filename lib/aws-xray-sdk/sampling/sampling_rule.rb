require 'aws-xray-sdk/exceptions'
require 'aws-xray-sdk/sampling/reservoir'
require 'aws-xray-sdk/search_pattern'

module XRay
  # Service sampling rule data model
  class SamplingRule
    attr_reader :name, :priority,
                :request_count, :borrow_count, :sampled_count
    attr_accessor :reservoir, :rate

    # @param Struct defined here https://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/XRay/Types/SamplingRule.html.
    def initialize(record)
      @name = record.rule_name
      @priority = record.priority
      @rate = record.fixed_rate

      @host = record.host
      @method = record.http_method
      @path = record.url_path
      @service = record.service_name
      @service_type = record.service_type

      @reservoir_size = record.reservoir_size
      @reservoir = Reservoir.new
      reset_statistics

      @lock = Mutex.new
    end

    # Determines whether or not this sampling rule applies to
    # the incoming request based on some of the request's parameters.
    # Any Nil parameters provided will be considered as implicit matches
    # as the rule matching is a best effort.
    def applies?(sampling_req)
      return false if sampling_req.nil? || sampling_req.empty?

      host = sampling_req[:host]
      http_method = sampling_req[:http_method]
      url_path = sampling_req[:url_path]
      service = sampling_req[:service]

      host_match = !host || SearchPattern.wildcard_match?(pattern: @host, text: host)
      path_match = !url_path || SearchPattern.wildcard_match?(pattern: @path, text: url_path)
      method_match = !http_method || SearchPattern.wildcard_match?(pattern: @method, text: http_method)
      service_match = !service || SearchPattern.wildcard_match?(pattern: @service, text: service)

      # if sampling request contains service type we assmue
      # the origin (a.k.a AWS plugins are set and effective)
      if sampling_req.key?(:service_type)
        service_type = sampling_req[:service_type]
        service_type_match = SearchPattern.wildcard_match?(pattern: @service_type, text: service_type)
      else
        service_type_match = @service_type == '*'
      end
      host_match && path_match && method_match && service_match && service_type_match
    end

    def snapshot_statistics
      @lock.synchronize do
        report = {
          request_count: @request_count,
          borrow_count: @borrow_count,
          sampled_count: @sampled_count
        }
        reset_statistics
        report
      end
    end

    def merge(rule)
      @lock.synchronize do
        @request_count = rule.request_count
        @borrow_count = rule.borrow_count
        @sampled_count = rule.sampled_count
        @reservoir = rule.reservoir
        rule.reservoir = nil
      end
    end

    def borrowable?
      @reservoir_size != 0
    end

    # Return `true` if this rule is the default rule.
    def default?
      @name == 'Default'
    end

    def ever_matched?
      @request_count > 0
    end

    def time_to_report?
      @reservoir.time_to_report?
    end

    def increment_request_count
      @lock.synchronize do
        @request_count += 1
      end
    end

    def increment_borrow_count
      @lock.synchronize do
        @borrow_count += 1
      end
    end

    def increment_sampled_count
      @lock.synchronize do
        @sampled_count += 1
      end
    end

    private

    def reset_statistics
      @request_count = 0
      @borrow_count = 0
      @sampled_count = 0
    end
  end
end
