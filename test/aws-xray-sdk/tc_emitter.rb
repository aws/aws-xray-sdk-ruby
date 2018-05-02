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
end
