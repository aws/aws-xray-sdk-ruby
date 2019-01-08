require 'aws-xray-sdk/logger'
require 'aws-xray-sdk/context/context'
require 'aws-xray-sdk/exceptions'

module XRay
  # The default context storage management used by
  # the X-Ray recorder. It uses thread local to store
  # segments and subsegments.
  class DefaultContext
    include Context
    include Logging

    LOCAL_KEY = '_aws_xray_entity'.freeze
    CONTEXT_MISSING_KEY = 'AWS_XRAY_CONTEXT_MISSING'.freeze
    SUPPORTED_STRATEGY = %w[RUNTIME_ERROR LOG_ERROR IGNORE_ERROR].freeze
    DEFAULT_STRATEGY = SUPPORTED_STRATEGY[0]

    attr_reader :context_missing

    def initialize
      strategy = ENV[CONTEXT_MISSING_KEY] || DEFAULT_STRATEGY
      @context_missing = sanitize_strategy(strategy)
    end

    # @param [Entity] entity The entity to be stored in the context.
    def store_entity(entity:)
      Thread.current[LOCAL_KEY] = entity
    end

    # @return [Entity] The current active entity(could be segment or subsegment).
    def current_entity
      if entity = Thread.current[LOCAL_KEY]
        entity
      else
        handle_context_missing
      end
    end

    # Clear the current thread local storage on X-Ray related entities.
    def clear!
      Thread.current[LOCAL_KEY] = nil
    end

    # @param [Entity] entity The entity to inject.
    # @param [Thread] target_ctx Put the provided entity to the new thread.
    def inject_context(entity, target_ctx: nil)
      target_ctx ||= Thread.current
      target_ctx[LOCAL_KEY] = entity if entity
    end

    # When the current entity needs to be accessed but there is none,
    # it handles the missing context based on the configuration.
    # On `RUNTIME_ERROR` it raises `ContextMissingError`.
    # On 'LOG_ERROR' it logs an error message and return `nil`.
    def handle_context_missing
      case context_missing
      when 'RUNTIME_ERROR'
        raise ContextMissingError
      when 'LOG_ERROR'
        logger.error %(can not find the current context.)
      end
      nil
    end

    def context_missing=(v)
      strategy = ENV[CONTEXT_MISSING_KEY] || v
      @context_missing = sanitize_strategy(strategy)
    end

    private

    def sanitize_strategy(v)
      if SUPPORTED_STRATEGY.include?(v)
        v
      else
        logger.warn %(context missing #{v} is not supported, switch to default #{DEFAULT_STRATEGY}.)
        DEFAULT_STRATEGY
      end
    end
  end
end
