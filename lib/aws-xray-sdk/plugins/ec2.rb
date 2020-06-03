require 'net/http'
require 'json'
require 'aws-xray-sdk/logger'

module XRay
  module Plugins
    # A plugin that gets the EC2 instance-id and AZ if running on an EC2 instance.
    module EC2
      include Logging

      ORIGIN = 'AWS::EC2::Instance'.freeze

      # http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-instance-metadata.html#instancedata-data-retrieval
      METADATA_BASE_URL = 'http://169.254.169.254/latest'.freeze

      def self.aws
        @@aws = {}
        token = get_token
        ec2_metadata = get_metadata(token)
        @@aws = {
          ec2: ec2_metadata
        }
      end


      private # private methods

      def self.get_token
        token_uri = URI(METADATA_BASE_URL + '/api/token')
        begin
          req = Net::HTTP::Put.new(token_uri)
          req['X-aws-ec2-metadata-token-ttl-seconds'] = '60'
          res = Net::HTTP.start(token_uri.hostname) { |http|
            http.request(req)
          }
          if res.code == '200'
            res.body
          else
            raise(StandardError.new("Unsuccessful response:: " + res.code))
          end
        rescue StandardError => e
          Logging.logger.warn %(can not get the IMDSv2 token due to: #{e.message}.)
          ''
        end
      end

      def self.get_metadata(token)
        metadata_uri = URI(METADATA_BASE_URL + '/dynamic/instance-identity/document')
        begin
          req = Net::HTTP::Get.new(metadata_uri)
          if token != ''
            req['X-aws-ec2-metadata-token'] = token
          end
          res = Net::HTTP.start(metadata_uri.hostname) { |http|
            http.request(req)
          }
          if res.code == '200'
            return parse_metadata(res.body)
          else
            raise(StandardError.new("Unsuccessful response:: " + res.code))
          end
        rescue StandardError => e
          Logging.logger.warn %(can not get the ec2 instance metadata due to: #{e.message}.)
          {}
        end
      end

      def self.parse_metadata(json_str)
        metadata = {}
        data = JSON(json_str)
        metadata['instance_id'] = data['instanceId']
        metadata['availability_zone'] = data['availabilityZone']
        metadata['instance_type'] = data['instanceType']
        metadata['ami_id'] = data['imageId']

        metadata
      end
    end
  end
end
