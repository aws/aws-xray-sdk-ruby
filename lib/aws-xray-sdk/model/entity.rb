require 'securerandom'
require 'bigdecimal'
require 'multi_json'
require 'aws-xray-sdk/exceptions'
require 'aws-xray-sdk/model/cause'
require 'aws-xray-sdk/model/annotations'
require 'aws-xray-sdk/model/metadata'

module XRay
  # This module contains common properties and methods
  # used by segment and subsegment class.
  module Entity
    attr_reader :name, :exception, :cause, :namespace,
                :http_request, :http_response
    attr_accessor :parent, :throttle, :error, :fault, :sampled, :aws,
                  :start_time, :end_time

    HTTP_REQUEST_KEY = %I[url method user_agent client_ip x_forwarded_for].freeze
    HTTP_RESPONSE_KEY = %I[status content_length].freeze

    # Generates a random 8-digit hex number as the entity id and returns it.
    def id
      @id ||= begin
        SecureRandom.hex(8)
      end
    end

    def closed?
      @closed ||= false
    end

    # @param [Float] end_time End time on epoch.
    def close(end_time: nil)
      raise EntityClosedError if closed?
      @end_time = end_time || Time.now.to_f
      @closed = true
    end

    # @return [Array] The children subsegments of this entity.
    def subsegments
      @subsegments ||= []
    end

    # @param [Subsegment] subsegment Append the provided subsegment to children subsegments.
    def add_subsegment(subsegment:)
      raise EntityClosedError if closed?
      subsegment.sampled = sampled
      subsegment.parent = self
      subsegments << subsegment
      nil
    end

    # @param [Subsegment] subsegment Remove the provided subsegment from children subsegments.
    # @return [Subsegment] The deleted subsegment if the deletion is successful.
    def remove_subsegment(subsegment:)
      subsegments.delete(subsegment)
      subsegment
    end

    def annotations
      @annotations ||= Annotations.new(self)
    end

    def metadata(namespace: :default)
      @metadata ||= Metadata.new(self)
      @metadata.sub_meta(namespace)
    end

    # Set error/fault/throttle flags based on http status code.
    # This method is idempotent.
    # @param [Integer] status
    def apply_status_code(status:)
      raise EntityClosedError if closed?
      case status.to_i
      when 429
        @throttle = true
        @error = true
        @fault = false
      when 400..499
        @error = true
        @throttle = false
        @fault = false
      when 500..599
        @fault = true
        @error = false
        @throttle = false
      end

      @http_response ||= {}
      @http_response[:status] = status.to_i
    end

    # @param [Hash] request Supported keys are `:url`, `:user_agent`, `:client_ip`,
    #   `:x_forwarded_for`, `:method`. Value can be one of
    #   String or Integer or Boolean types depend on the key.
    def merge_http_request(request:)
      raise EntityClosedError if closed?
      request.delete_if { |k| !HTTP_REQUEST_KEY.include?(k) }
      @http_request ||= {}
      @http_request.merge!(request)
    end

    # @param [Hash] response Supported keys are `:status`, `:content_length`.
    #   Value can be one of String or Integer types depend on the key.
    def merge_http_response(response:)
      raise EntityClosedError if closed?
      response.delete_if { |k| !HTTP_RESPONSE_KEY.include?(k) }
      @http_response ||= {}
      @http_response.merge!(response)
      apply_status_code status: response[:status] if response.key?(:status)
    end

    # @param [Exception] exception The exception object to capture.
    # @param remote A boolean flag indicates whether the exception is
    #   returned from the downstream service.
    def add_exception(exception:, remote: false)
      raise EntityClosedError if closed?
      @fault = true
      @exception = exception
      if cause_id = find_root_cause(exception)
        @cause = Cause.new id: cause_id
      else
        @cause = Cause.new exception: exception, remote: remote
      end
    end

    # @return [String] Cause id is the id of the subsegment where
    #   the exception originally comes from.
    def cause_id
      return @cause.id if @cause
    end

    # @return [Hash] The hash that contains all attributes that will
    #   be later serialized and sent out.
    def to_h
      h = {
        name:       name,
        id:         id,
        start_time: start_time
      }
      if closed?
        h[:end_time] = end_time
      else
        h[:in_progress] = true
      end

      h[:subsegments] = subsegments.map(&:to_h) unless subsegments.empty?

      h[:aws] = aws if aws
      if http_request || http_response
        h[:http] = {}
        h[:http][:request] = http_request if http_request
        h[:http][:response] = http_response if http_response
      end
      if (a = annotations.to_h) && !a.empty?
        h[:annotations] = a
      end
      if (m = @metadata) && !m.to_h.empty?
        h[:metadata] = m.to_h
      end

      h[:parent_id] = parent.id if parent
      # make sure the value in hash can only be boolean true
      h[:fault] = !!fault if fault
      h[:error] = !!error if error
      h[:throttle] = !!throttle if throttle
      h[:cause] = cause.to_h if cause
      h
    end

    def to_json
      @to_json ||= begin
        MultiJson.dump(to_h)
      end
    end

    private

    def find_root_cause(e)
      subsegment = subsegments.find { |i| i.exception.hash == e.hash }
      return nil unless subsegment
      if cause_id = subsegment.cause_id
        cause_id
      else
        subsegment.id
      end
    end
  end
end
