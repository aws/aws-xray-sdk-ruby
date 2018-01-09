require 'aws-xray-sdk/model/segment'
require 'aws-xray-sdk/model/subsegment'

# Subsegment data model test suite
class TestSubsegment < Minitest::Test
  def test_minimal_subsegment
    segment = XRay::Segment.new name: name
    subsegment = XRay::Subsegment.new name: name, segment: segment
    assert_equal segment, subsegment.segment
    assert subsegment.sampled
    assert_nil subsegment.end_time
    refute_nil subsegment.start_time
    refute_nil subsegment.id
  end

  def test_minimal_json
    segment = XRay::Segment.new name: name
    subsegment = XRay::Subsegment.new name: name, segment: segment
    segment.add_subsegment subsegment: subsegment
    json = segment.to_json
    h = eval(json)
    refute_nil h[:subsegments]
    refute h[:subsegments].empty?

    sub_h = h[:subsegments][0]
    assert_equal 'subsegment', sub_h[:type]
    assert_equal segment.id, sub_h[:parent_id]
    assert_equal segment.trace_id, sub_h[:trace_id]
    assert sub_h[:in_progress]
    refute_nil sub_h[:start_time]
    refute sub_h.key?(:sql)
    refute sub_h.key?(:end_time)
  end

  def test_nested_subsegments
    segment = XRay::Segment.new name: name
    subseg1 = XRay::Subsegment.new name: name, segment: segment
    subseg2 = XRay::Subsegment.new name: name, segment: segment
    subseg3 = XRay::Subsegment.new name: name, segment: segment
    subseg4 = XRay::Subsegment.new name: name, segment: segment
    segment.add_subsegment subsegment: subseg1
    subseg1.add_subsegment subsegment: subseg2
    subseg1.add_subsegment subsegment: subseg3
    subseg3.add_subsegment subsegment: subseg4

    assert_equal 4, segment.subsegment_size
    assert_equal 4, segment.ref_counter

    subseg4.close
    subseg3.close
    assert_equal 2, segment.ref_counter

    subseg1.remove_subsegment subsegment: subseg3
    assert_equal 2, segment.subsegment_size
  end
end
