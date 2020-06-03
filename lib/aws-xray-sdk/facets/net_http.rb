require 'net/http'
require 'aws-xray-sdk/facets/helper'

module XRay
  # Patch net/http to be traced by X-Ray
  module NetHttp
    # Class level interceptor to capture http requests as subsegments
    module HTTPClassInterceptor
      def new(*options)
        o = super(*options)
        o
      end
    end

    # Instance level interceptor to capture http requests as subsegments
    module HTTPInstanceInterceptor
      include XRay::Facets::Helper

      def initialize(*options)
        super(*options)
      end

      # HTTP requests to AWS Lambda Ruby Runtime will have the address and port
      # matching the value set in ENV['AWS_LAMBDA_RUNTIME_API']
      def lambda_runtime_request?
        ENV['AWS_LAMBDA_RUNTIME_API'] == "#{address}:#{port}"
      end

      def xray_sampling_request?(req)
        req.path && (req.path == ('/GetSamplingRules') || req.path == ('/SamplingTargets'))
      end

      # Instance Metadata Service provides endpoint 169.254.169.254 to
      # provide EC2 metadata
      def ec2_metadata_request?(req)
        req.uri && req.uri.hostname == '169.254.169.254'
      end

      def request(req, body = nil, &block)
        # Do not trace requests to xray or aws lambda runtime or ec2 metadata endpoint
        if xray_sampling_request?(req) || lambda_runtime_request? || ec2_metadata_request?(req)
          return super
        end

        entity = XRay.recorder.current_entity
        capture = !(entity && entity.namespace && entity.namespace == 'aws'.freeze)
        if started? && capture && entity
          XRay.recorder.capture(address, namespace: 'remote') do |subsegment|
            protocol = use_ssl? ? 'https'.freeze : 'http'.freeze
            # avoid modifying original variable
            iport = port.nil? ? nil : %(:#{port})
            # do not capture query string
            path = req.path.split('?')[0] if req.path
            uri = %(#{protocol}://#{address}#{iport}#{path})
            req_meta = {
              url: uri,
              method: req.method
            }
            subsegment.merge_http_request request: req_meta
            req[TRACE_HEADER] = prep_header_str entity: subsegment
            begin
              res = super
              res_meta = {
                status: res.code.to_i,
                content_length: res.content_length
              }
              subsegment.merge_http_response response: res_meta
              res
            rescue Exception => e
              subsegment.add_exception exception: e
              raise e
            end
          end
        else
          super
        end
      end
    end

    ::Net::HTTP.singleton_class.prepend HTTPClassInterceptor
    ::Net::HTTP.prepend HTTPInstanceInterceptor
  end
end
