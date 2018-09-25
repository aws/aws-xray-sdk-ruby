require 'aws-xray-sdk/exceptions'

module XRay
  # The class that stores X-Ray daemon configuration about
  # the ip address and port for UDP and TCP port. It gets the address
  # string from `AWS_XRAY_DAEMON_ADDRESS` and then from recorder's
  # configuration for `daemon_address`.
  # A notation of `127.0.0.1:2000` or `tcp:127.0.0.1:2000 udp:127.0.0.2:2001`
  # are both acceptable. The former one means UDP and TCP are running at
  # the same address. By default it assumes a X-Ray daemon
  # running at `127.0.0.1:2000` listening to both UDP and TCP traffic.
  class DaemonConfig
    DAEMON_ADDRESS_KEY = 'AWS_XRAY_DAEMON_ADDRESS'.freeze
    attr_reader :tcp_ip, :tcp_port, :udp_ip, :udp_port
    @@dafault_addr = '127.0.0.1:2000'

    def initialize(addr: @@dafault_addr)
      update_address(addr)
    end

    def update_address(v)
      v = ENV[DAEMON_ADDRESS_KEY] || v
      update_addr(v)
    rescue StandardError
      raise InvalidDaemonAddressError, %(Invalid X-Ray daemon address specified: #{v}.)
    end

    private

    def update_addr(v)
      parts = v.split(' ')
      if parts.length == 1 # format of '127.0.0.1:2000'
        addr = parts[0].split(':')
        raise InvalidDaemonAddressError unless addr.length == 2
        @tcp_ip = addr[0]
        @tcp_port = addr[1].to_i
        @udp_ip = addr[0]
        @udp_port = addr[1].to_i
      else
        set_tcp_udp(parts) # format of 'tcp:127.0.0.1:2000 udp:127.0.0.2:2001'
      end
    end

    def set_tcp_udp(parts)
      part1 = parts[0]
      part2 = parts[1]
      key1 = part1.split(':')[0]
      key2 = part2.split(':')[0]
      addr_h = {}
      addr_h[key1] = part1.split(':')
      addr_h[key2] = part2.split(':')

      @tcp_ip = addr_h['tcp'][1]
      @tcp_port = addr_h['tcp'][2].to_i
      @udp_ip = addr_h['udp'][1]
      @udp_port = addr_h['udp'][2].to_i
    end
  end
end
