require 'open-uri'
require 'aws-xray-sdk/logger'

module XRay
  module Plugins
    # A plugin that gets the EC2 instance-id and AZ if running on an EC2 instance.
    module EC2
      include Logging

      ORIGIN = 'AWS::EC2::Instance'.freeze
      # http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-instance-metadata.html#instancedata-data-retrieval
      ID_ADDR = 'http://169.254.169.254/latest/meta-data/instance-id'.freeze
      AZ_ADDR = 'http://169.254.169.254/latest/meta-data/placement/availability-zone'.freeze

      def self.aws
        @@aws ||= begin
          instance_id = open(ID_ADDR, open_timeout: 1).read
          az = open(AZ_ADDR, open_timeout: 1).read
          {
            ec2: {
              instance_id: instance_id,
              availability_zone: az
            }
          }
        rescue StandardError => e
          # Two attempts in total to get EC2 metadata
          @retries ||= 0
          if @retries < 1
            @retries += 1
            retry
          else
            @@aws = {}
            Logging.logger.warn %(can not get the ec2 instance metadata due to: #{e.message}.)
          end
        end
      end
    end
  end
end
