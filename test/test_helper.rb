require 'simplecov'
SimpleCov.start

require 'minitest/autorun'
require 'aws-xray-sdk/emitter/emitter'
require 'aws-xray-sdk/sampling/default_sampler'

if RUBY_PLATFORM == 'java'
  require 'jrjackson'
else
  require 'oj'
end

module XRay
  # holds all testing needed classes and methods
  module TestHelper
    # Emitter for testing that holds all entity it is about to send.
    class StubbedEmitter
      include Emitter

      attr_reader :entities

      def send_entity(entity:)
        @entities ||= []
        @entities << entity
      end

      def clear
        @entities = []
      end
    end

    # The stubbed sampler doesn't spawn threads to call X-Ray service.
    class StubbedDefaultSampler < DefaultSampler
      def start
        # no-op
      end
    end
  end
end
