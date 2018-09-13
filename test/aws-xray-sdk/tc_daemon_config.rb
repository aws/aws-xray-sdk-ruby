require_relative '../test_helper'
require 'aws-xray-sdk/daemon_config'
require 'aws-xray-sdk/exceptions'

# Test daemon configuration
class TestDaemonConfig < Minitest::Test
  def test_single_address
    ip = '192.168.0.1'
    port = 8000
    config = XRay::DaemonConfig.new addr: %(#{ip}:#{port})

    assert_equal config.udp_ip, ip
    assert_equal config.udp_port, port
    assert_equal config.tcp_ip, ip
    assert_equal config.tcp_port, port
  end

  def test_tcp_and_udp
    tcp_ip = '192.168.0.1'
    tcp_port = 8000
    udp_ip = '127.0.0.1'
    udp_port = 3000
    tcp = %(tcp:#{tcp_ip}:#{tcp_port})
    udp = %(udp:#{udp_ip}:#{udp_port})

    config = XRay::DaemonConfig.new addr: %(#{tcp} #{udp})

    assert_equal udp_ip, config.udp_ip
    assert_equal udp_port, config.udp_port
    assert_equal tcp_ip, config.tcp_ip
    assert_equal tcp_port, config.tcp_port

    config.update_address %(#{udp} #{tcp})

    assert_equal udp_ip, config.udp_ip
    assert_equal udp_port, config.udp_port
    assert_equal tcp_ip, config.tcp_ip
    assert_equal tcp_port, config.tcp_port
  end

  def test_invalid_config
    assert_raises XRay::InvalidDaemonAddressError do
      XRay::DaemonConfig.new addr: 'tcp:127.0.0.1:2000'
    end

    assert_raises XRay::InvalidDaemonAddressError do
      XRay::DaemonConfig.new addr: '127.0.0.1'
    end

    assert_raises XRay::InvalidDaemonAddressError do
      XRay::DaemonConfig.new addr: 'tcp:127.0.0.1:2000 tcp:127.0.0.1:3000'
    end

    assert_raises XRay::InvalidDaemonAddressError do
      XRay::DaemonConfig.new addr: 'tcp:127.0.0.1:2000udp:127.0.0.1:3000'
    end  
  end
end
