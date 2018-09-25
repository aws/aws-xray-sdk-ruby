require 'socket'
require 'aws-xray-sdk/logger'
require 'aws-xray-sdk/emitter/emitter'
require 'aws-xray-sdk/exceptions'
require 'aws-xray-sdk/daemon_config'

module XRay
  # The default emitter the X-Ray recorder uses to send segments/subsegments
  # to the X-Ray daemon over UDP using a non-blocking socket.
  class DefaultEmitter
    include Emitter
    include Logging

    attr_reader :daemon_config

    def initialize(daemon_config: DaemonConfig.new)
      @socket = UDPSocket.new
      self.daemon_config = daemon_config
    end

    # Serializes a segment/subsegment and sends it to the X-Ray daemon
    # over UDP. It is no-op for non-sampled entity.
    # @param [Entity] entity The entity to send
    def send_entity(entity:)
      return nil unless entity.sampled
      begin
        payload = %(#{@@protocol_header}#{@@protocol_delimiter}#{entity.to_json})
        logger.debug %(sending payload #{payload} to daemon at #{@address}.)
        @socket.send payload, 0
      rescue StandardError => e
        logger.warn %(failed to send payload due to #{e.message})
      end
    end

    def daemon_config=(v)
      @address = %(#{v.udp_ip}:#{v.udp_port})
      @socket.connect(v.udp_ip, v.udp_port)
    rescue StandardError
      raise InvalidDaemonAddressError, %(Invalid X-Ray daemon address specified: #{v}.)
    end
  end
end
