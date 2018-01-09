require 'socket'
require 'aws-xray-sdk/logger'
require 'aws-xray-sdk/emitter/emitter'
require 'aws-xray-sdk/exceptions'

module XRay
  # The default emitter the X-Ray recorder uses to send segments/subsegments
  # to the X-Ray daemon over UDP using a non-blocking socket.
  class DefaultEmitter
    include Emitter
    include Logging

    attr_reader :address

    def initialize
      @socket = UDPSocket.new
      @address = ENV[DAEMON_ADDRESS_KEY] || '127.0.0.1:2000'
      configure_socket(@address)
    end

    # Serializes a segment/subsegment and sends it to the X-Ray daemon
    # over UDP. It is no-op for non-sampled entity.
    # @param [Entity] entity The entity to send
    def send_entity(entity:)
      return nil unless entity.sampled
      begin
        payload = %(#{@@protocol_header}#{@@protocol_delimiter}#{entity.to_json})
        logger.debug %(sending payload #{payload} to daemon at #{address}.)
        @socket.send payload, 0
      rescue StandardError => e
        logger.warn %(failed to send payload due to #{e.message})
      end
    end

    def daemon_address=(v)
      v = ENV[DAEMON_ADDRESS_KEY] || v
      @address = v
      configure_socket(v)
    end

    private

    def configure_socket(v)
      begin
        addr = v.split(':')
        host, ip = addr[0], addr[1].to_i
        @socket.connect(host, ip)
      rescue StandardError
        raise InvalidDaemonAddressError, %(Invalid X-Ray daemon address specified: #{v}.)
      end
    end
  end
end
