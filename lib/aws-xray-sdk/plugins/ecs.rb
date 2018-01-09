require 'socket'
require 'aws-xray-sdk/logger'

module XRay
  module Plugins
    # Due to lack of ECS container metadata service, the only host information
    # available is the host name.
    module ECS
      include Logging

      ORIGIN = 'AWS::ECS::Container'.freeze

      def self.aws
        @@aws ||= begin
          { ecs: { container: Socket.gethostname } }
        rescue StandardError => e
          @@aws = {}
          Logging.logger.warn %(can not get the ecs container hostname due to: #{e.message}.)
        end
      end
    end
  end
end
