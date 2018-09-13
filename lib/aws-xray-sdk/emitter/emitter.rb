require 'json'

module XRay
  # The emitter interface the X-Ray recorder uses to send segments/subsegments
  # to the X-Ray daemon over UDP.
  module Emitter
    @@protocol_header = {
      format:   'json',
      version:  1
    }.to_json
    @@protocol_delimiter = "\n"

    # @param [Entity] entity Entity to send.
    def send_entity(entity:)
      raise 'Not implemented'
    end

    def daemon_config=(v)
      raise 'Not implemented'
    end
  end
end
