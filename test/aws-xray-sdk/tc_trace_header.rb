require 'aws-xray-sdk/model/trace_header'

# Test TraceHeader data model
class TestTraceHeader < Minitest::Test
  TRACE_ID = '1-5759e988-bd862e3fe1be46a994272793'.freeze
  PARENT_ID = '53995c3f42cd8ad8'.freeze

  def test_no_sample
    header = XRay::TraceHeader.new root: TRACE_ID, parent_id: PARENT_ID, sampled: nil
    refute header.sampled
    assert_equal TRACE_ID, header.root
    assert_equal PARENT_ID, header.parent_id
    assert_equal %(Root=#{TRACE_ID};Parent=#{PARENT_ID}), header.header_string
  end

  def test_no_parent
    header = XRay::TraceHeader.new root: TRACE_ID, parent_id: nil, sampled: 1
    assert_equal 1, header.sampled
    assert_equal TRACE_ID, header.root
    assert_equal %(Root=#{TRACE_ID};Sampled=1), header.header_string
  end

  def test_from_full_header_str
    header_str = %(Root=#{TRACE_ID};Parent=#{PARENT_ID};Sampled=0)
    header = XRay::TraceHeader.from_header_string header_str: header_str
    assert_equal 0, header.sampled
    assert_equal TRACE_ID, header.root
    assert_equal PARENT_ID, header.parent_id
  end

  def test_from_partial_header_str
    # missing parent_id
    header_str1 = %(Root=#{TRACE_ID};Sampled=0)
    header = XRay::TraceHeader.from_header_string header_str: header_str1
    assert_equal 0, header.sampled
    assert_equal TRACE_ID, header.root
    refute header.parent_id

    # missing sampling
    header_str2 = %(Root=#{TRACE_ID};Parent=#{PARENT_ID})
    header = XRay::TraceHeader.from_header_string header_str: header_str2
    assert_equal PARENT_ID, header.parent_id
    assert_equal TRACE_ID, header.root
    refute header.sampled
  end

  def test_invalid_header_str
    header_str = 'some random header string'
    header = XRay::TraceHeader.from_header_string header_str: header_str
    refute header.sampled
    refute header.root
    refute header.parent_id
  end

  def test_header_str_variant
    # casing and whitespaces
    header_str = %(ROOT=#{TRACE_ID}; PARENT=#{PARENT_ID}; SAMPLED=1)
    header = XRay::TraceHeader.from_header_string header_str: header_str
    assert_equal 1, header.sampled
    assert_equal TRACE_ID, header.root
    assert_equal PARENT_ID, header.parent_id
  end
end
