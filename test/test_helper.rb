require 'simplecov'
SimpleCov.start

require 'minitest/autorun'
require 'aws-xray-sdk/emitter/emitter'

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
  end
end
