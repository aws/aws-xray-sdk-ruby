require 'rack/request'
require 'aws-xray-sdk'
require 'aws-xray-sdk/facets/helper'

module XRay
  module Rack
    # Rack middleware that generates a segment for each request/response cycle.
    class Middleware
      include XRay::Facets::Helper
      X_FORWARD = 'HTTP_X_FORWARDED_FOR'.freeze
      SCHEME_SEPARATOR = "://".freeze

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
        # get segment name from host header if applicable
        seg_name = @recorder.segment_naming.provide_name(host: req.host)

        # get sampling decision
        sampled = should_sample?(
          header_obj: header, recorder: @recorder, sampling_req:
          { host: host, http_method: method, url_path: url_path, service: seg_name }
        )

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
          trace_header = {TRACE_HEADER => TraceHeader.from_entity(entity: segment).root_string}
          headers.merge!(trace_header)
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
        req_meta[:url] = req.scheme + SCHEME_SEPARATOR if req.scheme
        req_meta[:url] += req.host_with_port if req.host_with_port
        req_meta[:url] += req.path if req.path
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

      # get the last ip from header string
      def get_ip(v)
        ips = v.split(',')
        ips[ips.length - 1]
      end
    end
  end
end
