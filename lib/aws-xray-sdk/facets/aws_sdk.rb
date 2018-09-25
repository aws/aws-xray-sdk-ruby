require 'aws-sdk-core'
require 'aws-xray-sdk/facets/helper'
require 'aws-xray-sdk/facets/resources/aws_params_whitelist'
require 'aws-xray-sdk/facets/resources/aws_services_whitelist'

module XRay
  class AwsSDKPlugin < Seahorse::Client::Plugin
    option :xray_recorder, default: XRay.recorder

    def add_handlers(handlers, config)
      # run before Seahorse::Client::Plugin::ParamValidator (priority 50)
      handlers.add Handler, step: :validate, priority: 49
    end

    # Handler to capture AWS API calls as subsegments
    class Handler < Seahorse::Client::Handler
      include XRay::Facets::Helper

      def call(context)
        operation = context.operation_name
        service_name = context.client.class.api.metadata['serviceAbbreviation'] ||
                       context.client.class.to_s.split('::')[1]
        if skip?(service_name, operation)
          return super
        end

        recorder = Aws.config[:xray_recorder]
        if recorder.nil? || recorder.current_entity.nil?
          return super
        end

        recorder.capture(service_name, namespace: 'aws') do |subsegment|
          # inject header string before calling downstream AWS services
          context.http_request.headers[TRACE_HEADER] = prep_header_str entity: subsegment
          response = @handler.call(context)
          http_response = context.http_response
          resp_meta = {
            status: http_response.status_code,
            content_length: http_response.headers['content-length'].to_i
          }
          aws = {
            # XRay back-end right now has strict operation name matching
            operation: sanitize_op_name(operation),
            region: context.client.config.region,
            retries: context.retries,
            request_id: http_response.headers['x-amzn-requestid']
          }
          # S3 returns special request id in response headers
          if service_name == 'S3'
            aws[:id_2] = http_response.headers['x-amz-id-2']
          end

          operation_h = AwsParams.whitelist[:services]
                                 .fetch(service_name.to_sym, {})
                                 .fetch(:operations, {})[operation]
          unless operation_h.nil?
            params_capture req_params: context.params, resp_params: response.to_h,
                           capture: operation_h, meta: aws
          end
          subsegment.aws = aws
          if err = response.error
            subsegment.add_exception exception: err, remote: true
          end
          subsegment.merge_http_response response: resp_meta
          response
        end
      end

      private

      def inject_headers(request:, entity:)
        request.headers[TRACE_HEADER] = prep_header_str entity: entity
      end

      def sanitize_op_name(opname)
        opname.to_s.split('_').collect(&:capitalize).join if opname
      end

      def params_capture(req_params:, resp_params:, capture:, meta:)
        if norm = capture[:request_parameters]
          capture_normal params: req_params, capture: norm, meta: meta
        end

        if norm = capture[:response_parameters]
          capture_normal params: resp_params, capture: norm, meta: meta
        end

        if spec = capture[:request_descriptors]
          capture_special params: req_params, capture: spec, meta: meta
        end

        if spec = capture[:response_descriptors]
          capture_special params: resp_params, capture: spec, meta: meta
        end
      end

      def capture_normal(params:, capture:, meta:)
        params.each_key do |key|
          meta[key] = params[key] if capture.include?(key)
        end
      end

      def capture_special(params:, capture:, meta:)
        params.each_key do |key|
          process_descriptor(target: params[key], descriptor: capture[key], meta: meta) if capture.include?(key)
        end
      end

      def process_descriptor(target:, descriptor:, meta:)
        # "get_count" = true
        v = target.length if descriptor[:get_count]
        # "get_keys" = true
        v = target.keys if descriptor[:get_keys]
        meta[descriptor[:rename_to]] = v
      end

      def skip?(service, op)
        return service == 'XRay' && (op == :get_sampling_rules || op == :get_sampling_targets)
      end
    end
  end

  # Add X-Ray plugin to AWS SDK clients
  module AwsSDKPatcher
    def self.patch(services: nil, recorder: XRay.recorder)
      force = services.nil?
      services ||= AwsServices.whitelist
      services.each do |s|
        begin
          Aws.const_get(%(#{s}::Client)).add_plugin XRay::AwsSDKPlugin
          Aws.config.update xray_recorder: recorder
        rescue NameError
          # swallow the error if no explicit user config
          raise unless force
        end
      end
    end
  end
end
