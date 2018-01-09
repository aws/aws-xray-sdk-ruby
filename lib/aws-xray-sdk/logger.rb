require 'logger'

module XRay
  # Provide global logger for classes that include this module.
  # It serves as a proxy to global recorder's logger.
  module Logging
    def logger
      Logging.logger
    end

    def self.logger
      @logger ||= Logger.new($stdout).tap { |l| l.level = Logger::INFO }
    end

    def self.logger=(v)
      @logger = v
    end
  end
end
