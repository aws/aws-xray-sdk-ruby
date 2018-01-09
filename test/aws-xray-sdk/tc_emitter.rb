require 'aws-xray-sdk/emitter/default_emitter'
require 'aws-xray-sdk/model/segment'
require 'aws-xray-sdk/exceptions'

class TestEmitter < Minitest::Test
  def test_pass_through
    segment = XRay::Segment.new name: name
    segment.close
    emitter = XRay::DefaultEmitter.new
    emitter.send_entity entity: segment
  end

  def test_invalid_daemon_address
    segment = XRay::Segment.new name: name
    segment.close
    assert_raises XRay::InvalidDaemonAddressError do
      emitter = XRay::DefaultEmitter.new
      emitter.daemon_address = 'blah'
    end
    assert_raises XRay::InvalidDaemonAddressError do
      emitter = XRay::DefaultEmitter.new
      emitter.daemon_address = '127.0.0.1'
    end
  end
end
