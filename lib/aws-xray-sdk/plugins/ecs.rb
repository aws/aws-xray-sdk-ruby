require 'socket'
require 'aws-xray-sdk/logger'

module XRay
  module Plugins
    module ECS
      include Logging

      ORIGIN = 'AWS::ECS::Container'.freeze

      # Only compatible with v4!
      # The v3 metadata url does not contain cloudwatch informations
      METADATA_ENV_KEY = 'ECS_CONTAINER_METADATA_URI_V4'

      def self.aws
        metadata = get_metadata()

        begin
          metadata[:ecs][:container] = Socket.gethostname
        rescue StandardError => e
          Logging.logger.warn %(cannot get the ecs container hostname due to: #{e.message}.)
          metadata[:ecs][:container] = nil
        end

        @@aws = {
          ecs: metadata[:ecs],
          cloudwatch_logs: metadata[:cloudwatch_logs]
        }
      end

      private

      def self.get_metadata()
        begin
          metadata_uri = URI(ENV[METADATA_ENV_KEY])
          req = Net::HTTP::Get.new(metadata_uri)
          metadata_json = do_request(req)
          return parse_metadata(metadata_json)
        rescue StandardError => e
          Logging.logger.warn %(cannot get the ecs instance metadata due to: #{e.message}. Make sure you are using Fargate platform version >=1.4.0)
          { ecs: {}, cloudwatch_logs: {} }
        end
      end

      def self.parse_metadata(json_str)
        data = JSON(json_str)

        metadata = {
          ecs: {
            container_arn: data['ContainerARN'],
          },
          cloudwatch_logs: {
            log_group: data["LogOptions"]['awslogs-group'],
            log_region: data["LogOptions"]['awslogs-region'],
            arn: data['ContainerARN']
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
