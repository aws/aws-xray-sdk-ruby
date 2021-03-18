require 'minitest/autorun'
require 'aws-xray-sdk/model/segment'

class TestDistribution< Minitest::Test
  # Simple test to ensure gem was initialized correctly
  def test_segment
    segment = XRay::Segment.new trace_id: '123'
    assert_equal '123', segment.trace_id
  end
end
