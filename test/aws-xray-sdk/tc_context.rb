require 'aws-xray-sdk/exceptions'
require 'aws-xray-sdk/model/segment'
require 'aws-xray-sdk/context/default_context'

# Test context management
class TestContext < Minitest::Test
  def test_segment_crud
    context = XRay::DefaultContext.new
    context.clear!
    segment = XRay::Segment.new name: name
    context.store_entity entity: segment
    assert_equal segment, context.current_entity
    segment2 = XRay::Segment.new name: name
    context.store_entity entity: segment2
    assert_equal segment2, context.current_entity
    context.clear!
  end

  def test_change_context_missing
    context = XRay::DefaultContext.new
    context.clear!
    context.context_missing = 'UNKWON'
    assert_equal 'RUNTIME_ERROR', context.context_missing
    context.context_missing = 'LOG_ERROR'
    assert_equal 'LOG_ERROR', context.context_missing
  end

  def test_runtime_error
    context = XRay::DefaultContext.new
    context.clear!
    assert_raises XRay::ContextMissingError do
      context.current_entity
    end
  end

  def test_log_error
    context = XRay::DefaultContext.new
    context.clear!
    context.context_missing = 'LOG_ERROR'
    refute context.current_entity
  end
end
