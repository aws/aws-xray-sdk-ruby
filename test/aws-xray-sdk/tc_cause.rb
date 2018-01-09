require_relative '../test_helper'
require 'aws-xray-sdk/model/segment'
require 'aws-xray-sdk/model/subsegment'

# Test exception recording
class TestCauses < Minitest::Test
  def test_simple_exception
    segment = XRay::Segment.new name: name
    begin
      1 / 0
    rescue ZeroDivisionError => e
      segment.add_exception exception: e
    end

    assert segment.fault
    # check top level fields
    h = segment.cause.to_h
    assert_equal 1, h[:exceptions].count
    assert_nil h[:remote]
    refute_nil h[:working_directory]
    refute_nil h[:paths]

    # check exception entry
    eh = h[:exceptions][0]
    assert_equal 'ZeroDivisionError', eh[:type]
    refute_nil eh[:message]

    # check stack entry
    stack = eh[:stack][0]
    assert stack[:line].is_a?(Integer)
    refute_nil stack[:label]
    refute_nil stack[:path]
  end

  def test_remote_flag
    segment = XRay::Segment.new name: name
    begin
      raise StandardError
    rescue StandardError => e
      segment.add_exception exception: e, remote: true
    end
    exception = segment.cause.to_h[:exceptions][0]
    assert_equal true, exception[:remote]
  end

  def test_chained_exception
    segment = XRay::Segment.new name: name
    begin
      fail_and_raise
    rescue StandardError => e
      segment.add_exception exception: e
    end

    # check top level fields
    h = segment.cause.to_h
    assert_equal 2, h[:exceptions].count

    # check exceptions type
    exceptions = h[:exceptions]
    assert_equal 'StandardError', exceptions[0][:type]
    assert_equal 'ZeroDivisionError', exceptions[1][:type]
  end

  def test_duplicate_exception
    segment = XRay::Segment.new name: name
    subsegment = XRay::Subsegment.new name: name, segment: segment
    segment.add_subsegment subsegment: subsegment
    begin
      1 / 0
    rescue ZeroDivisionError => e
      subsegment.add_exception exception: e
      segment.add_exception exception: e
    end

    assert_equal subsegment.id, segment.cause_id
    cause_id = segment.to_h[:cause]
    assert_equal subsegment.id, cause_id
  end

  private

  def fail_and_raise
    raise ZeroDivisionError
  rescue
    raise StandardError
  end
end
