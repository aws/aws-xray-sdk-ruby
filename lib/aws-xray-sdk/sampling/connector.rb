require 'securerandom'
require 'aws-xray-sdk/sampling/sampling_rule'
require 'aws-xray-sdk/logger'

module XRay
  # Connector class that translates Sampling poller functions to
  # actual X-Ray back-end APIs and communicates with X-Ray daemon
  # as the signing proxy.
  class ServiceConnector
    include Logging
    attr_accessor :xray_client

    def initialize
      update_xray_client
    end

    def fetch_sampling_rules
      rules = []
      records = @xray_client.get_sampling_rules.sampling_rule_records
      records.each { |record| rules << SamplingRule.new(record.sampling_rule) if rule_valid?(record.sampling_rule) }
      rules
    end

    def fetch_sampling_targets(rules)
      now = Time.now.to_i
      reports = generate_reports(rules, now)
      resp = @xray_client.get_sampling_targets({ sampling_statistics_documents: reports })
      {
        last_modified: resp.last_rule_modification,
        documents: resp.sampling_target_documents
      }
    end

    def update_xray_client(ip: '127.0.0.1', port: 2000)
      require 'aws-sdk-xray'
      @xray_client = Aws::XRay::Client.new(
        endpoint: %(http://#{ip}:#{port}),
        access_key_id: 'dummy', # AWS Ruby SDK doesn't support unsigned request
        secret_access_key: 'dummy',
        region: 'us-west-2' # not used
      )
    end

    def daemon_config=(v)
      update_xray_client ip: v.tcp_ip, port: v.tcp_port
    end

    def client_id
      @client_id ||= begin
        SecureRandom.hex(12) 
      end
    end

    private

    def generate_reports(rules, now)
      reports = []
      rules.each do |rule|
        report = rule.snapshot_statistics
        report[:rule_name] = rule.name
        report[:timestamp] = now
        report[:client_id] = client_id
        reports << report
      end
      reports
    end

    def rule_valid?(rule)
      return false if rule.version != 1
      # rules has resource ARN and attributes configured
      # doesn't apply to this SDK
      return false unless rule.resource_arn == '*'
      return false unless rule.attributes.nil? || rule.attributes.empty?
      true
    end
  end
end
