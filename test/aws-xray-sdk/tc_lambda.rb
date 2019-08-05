require_relative '../test_helper'

require 'aws-xray-sdk/model/segment'
require 'aws-xray-sdk/lambda/facade_segment'

require 'aws-xray-sdk/context/default_context'
require 'aws-xray-sdk/lambda/lambda_context'

require 'aws-xray-sdk/streaming/default_streamer'
require 'aws-xray-sdk/lambda/lambda_streamer'

require 'aws-xray-sdk/lambda/lambda_recorder'


# Test lambda instrumentation
class TestLambda < Minitest::Test
  PARENT_ID = '53995c3f42cd8ad8'.freeze

  def teardown
    ENV[XRay::LambdaContext::TRACE_ID_ENV_VAR] = nil
  end

  def test_facade_segment_never_ready_to_send
    segment = XRay::FacadeSegment.new
    refute segment.ready_to_send?
  end
  def test_facade_segment_init
    trace_id='x-abc-123'
    name='segment-name'
    parent_id='parent-xyz'
    id='q-rst-uv'
    sampled=true
    segment=XRay::FacadeSegment.new(
      trace_id: trace_id,
      name: name,
      parent_id: parent_id,
      id: id,
      sampled: sampled
    )
    segment_hash=segment.to_h
    assert_equal(trace_id, segment_hash[:trace_id])
    assert_equal(name, segment_hash[:name])
    assert_equal(parent_id, segment_hash[:parent_id])
    assert_equal(id, segment_hash[:id])
    assert_equal(sampled, segment.sampled)
  end
  def test_facade_segment_unsupported_methods
    # ref_counter subsegment_size origin user service sampling_rule_name
    methods = {
      close: {end_time: nil},
      apply_status_code: {status: 200},
      merge_http_request: {request: nil},
      merge_http_response: {response: nil},
      add_exception: {exception: nil, remote: true}
    }
    methods.each_pair do |method, value|
      segment = XRay::FacadeSegment.new
      assert_raises XRay::UnsupportedOperationError do
        segment.send(method, value)
      end
    end
  end
  def test_facade_segment_unsupported_mutators
    %i( parent= throttle= error= fault= sampled= aws= start_time= end_time=
        origin= user= service=
      ).each do |accessor|
      segment = XRay::FacadeSegment.new
      assert_raises XRay::UnsupportedOperationError do
        segment.send(accessor, 'x')
      end
    end
  end
  def test_facade_segment_annotations_are_read_only
    segment = XRay::FacadeSegment.new
    assert_equal(segment.annotations.to_h, {})
    assert_raises XRay::UnsupportedOperationError do
        segment.annotations['x'] = 'y'
    end
    assert_raises XRay::UnsupportedOperationError do
      segment.annotations.update({x: 'y'})
    end
  end
  def test_facade_segment_metadata_is_read_only
    segment = XRay::FacadeSegment.new
    metadata = segment.metadata(namespace: 'a_namespace')
    assert_equal(metadata.to_h, {})
    assert_raises XRay::UnsupportedOperationError do
        metadata['x'] = 'y'
    end
    assert_raises XRay::UnsupportedOperationError do
      metadata.update({x: 'y'})
    end
  end
  def test_facade_segment_can_add_subsegment
    segment = XRay::FacadeSegment.new
    sub1 = XRay::Subsegment.new(name: 'sub1', segment: segment)
    segment.add_subsegment(subsegment: sub1)
    sub2 = XRay::Subsegment.new(name: 'sub2', segment: segment)
    sub1.add_subsegment(subsegment: sub2)
  end

  def test_lambda_context_reads_trace_id
    trace_id = XRay::Segment.new.trace_id
    ENV[XRay::LambdaContext::TRACE_ID_ENV_VAR] = trace_id
    context = XRay::LambdaContext.new
    assert_equal(trace_id, context.lambda_trace_id)
  end
  def test_lambda_context_current_entity_is_a_facade
    trace_id = XRay::Segment.new.trace_id
    header_str = %(ROOT=#{trace_id}; PARENT=#{PARENT_ID}; SAMPLED=1)
    ENV[XRay::LambdaContext::TRACE_ID_ENV_VAR] = header_str
    context = XRay::LambdaContext.new
    entity = context.current_entity

    assert_instance_of(XRay::FacadeSegment, entity)
    assert_equal(trace_id, entity.trace_id)
    assert_equal(PARENT_ID, entity.to_h[:parent_id])
  end
  def test_lambda_context_current_entity_changes_when_env_changes
    trace_id = XRay::Segment.new.trace_id
    header_str = %(ROOT=#{trace_id}; PARENT=#{PARENT_ID}; SAMPLED=1)
    ENV[XRay::LambdaContext::TRACE_ID_ENV_VAR] = header_str
    context = XRay::LambdaContext.new
    entity = context.current_entity

    assert_instance_of(XRay::FacadeSegment, entity)
    assert_equal(trace_id, entity.trace_id)
    assert_equal(PARENT_ID, entity.to_h[:parent_id])
    assert_equal(true, entity.sampled)

    trace_id_2 = XRay::Segment.new.trace_id
    refute_equal(trace_id_2, trace_id)
    header_str = %(ROOT=#{trace_id_2}; PARENT=#{PARENT_ID}; SAMPLED=0)

    ENV[XRay::LambdaContext::TRACE_ID_ENV_VAR] = header_str
    entity_2 = context.current_entity
    refute_equal(entity, entity_2)
    assert_instance_of(XRay::FacadeSegment, entity_2)
    assert_equal(trace_id_2, entity_2.trace_id)
    assert_equal(PARENT_ID, entity_2.to_h[:parent_id])
    assert_equal(false, entity_2.sampled)
  end

  def test_lambda_stream_threshold_is_one
    streamer = XRay::LambdaStreamer.new
    assert_equal(1, streamer.stream_threshold)
  end

  def test_lambda_recorder_begin_end_segment_is_noop
    trace_id = XRay::Segment.new.trace_id
    header_str = %(ROOT=#{trace_id}; PARENT=#{PARENT_ID}; SAMPLED=1)
    ENV[XRay::LambdaContext::TRACE_ID_ENV_VAR] = header_str

    recorder = XRay::LambdaRecorder.new
    recorder.configure( context: XRay::LambdaContext.new )
    entity = recorder.context.current_entity
    assert_equal(recorder.begin_segment('some_name'), entity) #calling begin_segment returns current entity
    assert_equal(recorder.context.current_entity, entity) #current entity is unchanged
    recorder.end_segment
    assert_equal(recorder.context.current_entity, entity) #current entity is unchanged
  end

end
