require 'bigdecimal'
require 'aws-xray-sdk/model/segment'
require 'aws-xray-sdk/model/subsegment'

# Segment data model test suite
class TestSegment < Minitest::Test
  def test_minimal_segment
    segment = XRay::Segment.new name: name
    assert_equal name, segment.name
    assert segment.sampled
    assert_nil segment.end_time
    refute_nil segment.start_time
    refute_nil segment.trace_id
    refute_nil segment.id
  end

  def test_minimal_json
    segment = XRay::Segment.new name: name
    segment.close
    json = segment.to_json
    h = eval(json)
    refute_nil h[:trace_id]
    refute_nil h[:id]
    refute_nil h[:start_time]
    refute_nil h[:end_time]
    refute h.key?(:error)
    refute h.key?(:throttle)
    refute h.key?(:fault)
    refute h.key?(:cause)
    refute h.key?(:metadata)
    refute h.key?(:annotations)
    refute h.key?(:user)
    refute h.key?(:parent_id)
    refute h.key?(:in_progress)
    refute h.key?(:subsegments)
    refute h.key?(:http)
    refute h.key?(:aws)
  end

  def test_apply_status_code
    segment1 = XRay::Segment.new name: name
    segment1.apply_status_code status: 200
    refute segment1.fault
    refute segment1.error
    refute segment1.throttle
    assert_equal 200, segment1.http_response[:status]

    segment2 = XRay::Segment.new name: name
    segment2.apply_status_code status: 500
    assert segment2.fault
    refute segment2.error
    refute segment2.throttle

    segment3 = XRay::Segment.new name: name
    segment3.apply_status_code status: 400
    assert segment3.error
    refute segment3.fault
    refute segment3.throttle

    segment4 = XRay::Segment.new name: name
    segment4.apply_status_code status: 429
    assert segment4.error
    assert segment4.throttle
    refute segment4.fault
  end

  def test_annotations
    segment = XRay::Segment.new name: name
    segment.annotations.update key1: 'value', key2: 2
    assert_equal segment.annotations[:key1], 'value'
    assert_equal segment.annotations[:key2], 2

    segment.annotations[:key2] = 3
    assert_equal segment.annotations.to_h, { key1: 'value' }.merge(key2: 3)

    # annotation key contains invalid character should be dropped.
    at3 = { 福: true }
    segment.annotations.update at3
    refute segment.annotations.to_h.key?(:福)

    # annotation value with unsupported type should be dropped.
    segment.annotations[:key3] = {}
    refute segment.annotations.to_h.key?(:key3)
  end

  def test_numeric_annotation_value
    segment = XRay::Segment.new name: name
    annotations = {
      k1: Rational(1 / 2),
      k2: BigDecimal(1),
      k3: 1 / 0.0, # Infinity
      k4: 0 / 0.0, # NaN
    }
    segment.annotations.update annotations
    h = eval(segment.to_json)
    at_h = h[:annotations]
    assert_equal 'Infinity', at_h[:k3]
    assert_equal 'NaN', at_h[:k4]
  end

  def test_add_subsegment
    segment = XRay::Segment.new name: name
    subsegment = XRay::Subsegment.new name: name, segment: segment
    segment.add_subsegment subsegment: subsegment
    assert_equal segment.ref_counter, 1
    assert_equal segment.subsegment_size, 1
    assert_equal segment.subsegments.count, 1
    assert_equal segment.subsegments[0], subsegment

    subsegment.close
    assert_equal segment.ref_counter, 0
    refute segment.ready_to_send?
  end

  def test_remove_subsegment
    segment = XRay::Segment.new name: name
    subsegment = XRay::Subsegment.new name: name, segment: segment
    segment.add_subsegment subsegment: subsegment
    segment.remove_subsegment subsegment: subsegment
    assert segment.subsegments.empty?
    assert_equal segment.subsegment_size, 0
  end

  def test_mutate_closed
    segment = XRay::Segment.new name: name
    segment.close
    assert_raises XRay::EntityClosedError do
      segment.close
    end

    assert_raises XRay::EntityClosedError do
      segment.annotations[:k] = 1
    end

    assert_raises XRay::EntityClosedError do
      subsegment = XRay::Subsegment.new name: name, segment: segment
      segment.add_subsegment subsegment: subsegment
    end
  end
end
