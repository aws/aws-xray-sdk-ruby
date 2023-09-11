require 'socket'
require 'aws-xray-sdk/logger'

module XRay
  module Plugins
    # Due to lack of ECS container metadata service, the only host information
    # available is the host name.
    module ECS
      include Logging

      ORIGIN = 'AWS::ECS::Container'.freeze

      METADATA_BASE_URL = 'http://169.254.169.254/latest'.freeze

      def self.aws
        @@aws = {}
        token = get_token
        metadata = get_metadata(token)

        @@aws = {
          ecs: { container: metadata[:ecs] },
          cloudwatch_logs: metadata[:cloudwatch_logs]
        }
      end

      private

      def self.get_token
        token_uri = URI(METADATA_BASE_URL + '/api/token')

        req = Net::HTTP::Put.new(token_uri)
        req['X-aws-ec2-metadata-token-ttl-seconds'] = '60'
        begin
          return do_request(req)
        rescue StandardError => e
          Logging.logger.warn %(cannot get the IMDSv2 token due to: #{e.message}.)
          ''
        end
      end

      def self.get_metadata(token)
        metadata_uri = URI(METADATA_BASE_URL + '/dynamic/instance-identity/document')

        req = Net::HTTP::Get.new(metadata_uri)
        if token != ''
          req['X-aws-ec2-metadata-token'] = token
        end

        begin
          metadata_json = do_request(req)
          return parse_metadata(metadata_json)
        rescue StandardError => e
          Logging.logger.warn %(cannot get the ec2 instance metadata due to: #{e.message}.)
          {}
        end
      end

      def self.parse_metadata(json_str)
        data = JSON(json_str)

        begin
          container_hostname = Socket.gethostname
        rescue StandardError => e
          @@aws = {}
          Logging.logger.warn %(cannot get the ecs container hostname due to: #{e.message}.)
        end

        metadata = {
          'ecs': {
            'container': container_hostname,
            'container_arn': data['ContainerARN'],
          },
          'cloudwatch_logs': {
            'log_driver': data['LogDriver'],
            'log_option': data['LogOptions'],
            'log_group': data['awslogs-group'],
            'log_region': data['awslogs-region'],
            'arn': data['ContainerARN']
          }
        }

        metadata
      end

      def self.do_request(request)
        begin
          response = Net::HTTP.start(request.uri.hostname, read_timeout: 1) { |http|
            http.request(request)
          }

          if response.code == '200'
            return response.body
          else
            raise(StandardError.new('Unsuccessful response::' + response.code + '::' + response.message))
          end
        rescue StandardError => e
          # Two attempts in total to complete the request successfully
          @retries ||= 0
          if @retries < 1
            @retries += 1
            retry
          else
            Logging.logger.warn %(Failed to complete request due to: #{e.message}.)
            raise e
          end
        end
      end
    end
  end
end
