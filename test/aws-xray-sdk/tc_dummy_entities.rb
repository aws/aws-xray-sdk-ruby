require 'aws-xray-sdk/model/dummy_entities'

# Test dummy segments and dummy subsegments
class TestDummyEntities < Minitest::Test
  def test_no_sample
    segment = XRay::DummySegment.new name: name
    refute segment.sampled
    subegment = XRay::DummySubsegment.new name: segment, segment: segment
    refute subegment.sampled
  end

  def test_no_meta
    segment = XRay::DummySegment.new name: name
    subegment = XRay::DummySubsegment.new name: 'dummy', segment: segment
    entities = [segment, subegment]
    entities.each do |e|
      e.metadata.update k: 'v'
      e.annotations.update k: 'v'
      e.merge_http_request request: { url: '/ping' }
      e.merge_http_response response: { status: 200 }
      e.aws = { sdk: 'ruby' }
    end

    entities.each do |e|
      refute e.aws
      refute e.http_request
      refute e.http_response
      refute e.annotations.to_h
      refute e.metadata.to_h
    end
  end

  def test_structure_intact
    segment = XRay::DummySegment.new name: name
    subsegment1 = XRay::DummySubsegment.new name: 'dummy', segment: segment
    subsegment2 = XRay::DummySubsegment.new name: 'dummy', segment: segment
    segment.add_subsegment subsegment: subsegment1
    subsegment1.add_subsegment subsegment: subsegment2

    assert_equal 2, segment.subsegment_size
    assert_equal 2, segment.ref_counter
    assert_equal subsegment1, segment.subsegments[0]
    assert_equal subsegment2, subsegment1.subsegments[0]
  end
end
