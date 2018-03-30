require 'multi_json'
require 'aws-xray-sdk/logger'

module XRay
  module Plugins
    # A plugin that records information about the elastic beanstalk environment
    # hosting your application.
    module ElasticBeanstalk
      include Logging

      CONF_PATH = '/var/elasticbeanstalk/xray/environment.conf'.freeze
      ORIGIN = 'AWS::ElasticBeanstalk::Environment'.freeze

      def self.aws
        @@aws ||= begin
          file = File.open(CONF_PATH)
          { elastic_beanstalk: MultiJson.load(file) }
        rescue StandardError => e
          @@aws = {}
          Logging.logger.warn %(can not get the environment config due to: #{e.message}.)
        end
      end
    end
  end
end
