require 'rack/request'
require 'aws-xray-sdk'
require 'aws-xray-sdk/facets/helper'

module XRay
  module Rack
    # Rack middleware that generates a segment for each request/response cycle.
    class Middleware
      include XRay::Facets::Helper
      X_FORWARD = 'HTTP_X_FORWARDED_FOR'.freeze

      def initialize(app, recorder: nil)
        @app = app
        @recorder = recorder || XRay.recorder
      end

      def call(env)
        header = construct_header(headers: env)
        req = ::Rack::Request.new(env)

        # params required for path based sampling
        host = req.host
        url_path = req.path
        method = req.request_method

        # get sampling decision
        sampled = should_sample?(
          header_obj: header, recorder: @recorder,
          host: host, method: method, path: url_path
        )

        # get segment name from host header if applicable
        seg_name = @recorder.segment_naming.provide_name(host: req.host)

        # begin the segment
        segment = @recorder.begin_segment seg_name, trace_id: header.root, parent_id: header.parent_id,
                                                    sampled: sampled

        # add neccessary http request metadata to the segment
        req_meta = extract_request_meta(req)
        segment.merge_http_request request: req_meta unless req_meta.empty?
        begin
          status, headers, body = @app.call env
          resp_meta = {}
          resp_meta[:status] = status
          # Don't set content_length if it is not available on headers.
          resp_obj = ::Rack::Response.new body: body, status: status, headers: headers
          if len = resp_obj.content_length
            resp_meta[:content_length] = len
          end
          segment.merge_http_response response: resp_meta
          [status, headers, body]
        rescue Exception => e
          segment.apply_status_code status: 500
          segment.add_exception exception: e
          raise e
        ensure
          @recorder.end_segment
        end
      end

      private

      def extract_request_meta(req)
        req_meta = {}
        req_meta[:url] = req.url if req.url
        req_meta[:user_agent] = req.user_agent if req.user_agent
        req_meta[:method] = req.request_method if req.request_method
        if req.has_header?(X_FORWARD)
          req_meta[:client_ip] = get_ip(req.get_header(X_FORWARD))
          req_meta[:x_forwarded_for] = true
        elsif v = req.ip
          req_meta[:client_ip] = v
        end
        req_meta
      end

      def get_ip(ips)
        if ips.respond_to?(:length)
          ips[ips.length - 1]
        else
          ips
        end
      end
    end
  end
end
