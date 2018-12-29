require 'aws-xray-sdk/exceptions'
require 'aws-xray-sdk/patcher'
require 'aws-xray-sdk/emitter/default_emitter'
require 'aws-xray-sdk/context/default_context'
require 'aws-xray-sdk/daemon_config'
require 'aws-xray-sdk/sampling/default_sampler'
require 'aws-xray-sdk/streaming/default_streamer'
require 'aws-xray-sdk/segment_naming/dynamic_naming'
require 'aws-xray-sdk/plugins/ec2'
require 'aws-xray-sdk/plugins/ecs'
require 'aws-xray-sdk/plugins/elastic_beanstalk'
require 'aws-xray-sdk/logger'

module XRay
  # This class stores all configurations for X-Ray recorder
  # and should be initialized only once.
  class Configuration
    include Patcher

    SEGMENT_NAME_KEY = 'AWS_XRAY_TRACING_NAME'.freeze
    CONFIG_KEY = %I[logger name sampling plugins daemon_address
                    segment_naming naming_pattern emitter streamer context
                    context_missing sampling_rules stream_threshold patch].freeze

    def initialize
      @name = ENV[SEGMENT_NAME_KEY]
      @sampling = true
      @emitter = DefaultEmitter.new
      @context = DefaultContext.new
      @sampler = DefaultSampler.new
      @streamer = DefaultStreamer.new
      @segment_naming = DynamicNaming.new fallback: @name
      @plugins = []
    end

    # @param [String] v The default segment name.
    #   Environment vairable takes higher precedence.
    def name=(v)
      @name = ENV[SEGMENT_NAME_KEY] || v
    end

    # setting daemon address for components communicate with X-Ray daemon.
    def daemon_address=(v)
      v = ENV[DaemonConfig::DAEMON_ADDRESS_KEY] || v
      config = DaemonConfig.new(addr: v)
      emitter.daemon_config = config
      sampler.daemon_config = config if sampler.respond_to?(:daemon_config=)
    end

    # proxy method to the context's context_missing config.
    def context_missing=(v)
      context.context_missing = v
    end

    # proxy method to the sampler's sampling rule config.
    def sampling_rules=(v)
      sampler.sampling_rules = v
    end

    # proxy method to the streamer's stream threshold config.
    def stream_threshold=(v)
      streamer.stream_threshold = v
    end

    # proxy method to the dynamic naming's pattern config.
    def naming_pattern=(v)
      segment_naming.pattern = v
    end

    # makes a sampling decision without incoming filters.
    def sample?
      return true unless sampling
      sampler.sample?
    end

    # @param [Hash] user_config The user configuration overrides.
    def configure(user_config)
      raise InvalidConfigurationError.new('User config must be a Hash.') unless user_config.is_a?(Hash)
      return if user_config.empty?

      user_config.each_key do |key|
        case key
        when :logger
          XRay::Logging.logger = user_config[key]
        when :name
          self.name = user_config[key]
        when :context
          self.context = user_config[key]
        when :context_missing
          self.context_missing = user_config[key]
        when :sampler
          self.sampler = user_config[key]
        when :sampling_rules
          self.sampling_rules = user_config[key]
        when :sampling
          self.sampling = user_config[key]
        when :emitter
          self.emitter = user_config[key]
        when :daemon_address
          self.daemon_address = user_config[key]
        when :segment_naming
          self.segment_naming = user_config[key]
        when :naming_pattern
          self.naming_pattern = user_config[key]
        when :streamer
          self.streamer = user_config[key]
        when :stream_threshold
          self.stream_threshold = user_config[key]
        when :plugins
          self.plugins = load_plugins(user_config[key])
        when :patch
          patch(user_config[key])
        else
          raise InvalidConfigurationError.new(%(Invalid config key #{key}.))
        end
      end
    end

    attr_accessor :emitter

    attr_accessor :context

    attr_accessor :sampler

    attr_accessor :streamer

    attr_accessor :segment_naming

    attr_accessor :plugins

    attr_accessor :sampling

    # @return [String] The default segment name.
    attr_reader :name

    # The global logger used across the X-Ray SDK.
    # @return [Logger]
    attr_reader :logger

    private

    def load_plugins(symbols)
      plugins = []
      symbols.each do |symbol|
        case symbol
        when :ec2
          plugins << XRay::Plugins::EC2
        when :ecs
          plugins << XRay::Plugins::ECS
        when :elastic_beanstalk
          plugins << XRay::Plugins::ElasticBeanstalk
        else
          raise InvalidConfigurationError.new(%(Unsupported plugin #{symbol}.))
        end
      end
      # eager loads aws metadata to eliminate impact on first incoming request
      plugins.each(&:aws)
      plugins
    end
  end
end
