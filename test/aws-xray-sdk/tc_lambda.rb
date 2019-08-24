require_relative '../test_helper'

require 'aws-xray-sdk/model/segment'
require 'aws-xray-sdk/lambda/facade_segment'

require 'aws-xray-sdk/context/default_context'
require 'aws-xray-sdk/lambda/lambda_context'

require 'aws-xray-sdk/emitter/default_emitter'
require 'aws-xray-sdk/lambda/lambda_emitter'

require 'aws-xray-sdk/streaming/default_streamer'
require 'aws-xray-sdk/lambda/lambda_streamer'

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
        ref_counter= subsegment_size= origin= user= service=
      ).each do |accessor|
      segment = XRay::FacadeSegment.new
      assert_raises XRay::UnsupportedOperationError do
        segment.send(accessor, 'x')
      end
    end
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

    trace_id_2 = XRay::Segment.new.trace_id
    refute_equal(trace_id_2, trace_id)
    header_str = %(ROOT=#{trace_id_2}; PARENT=#{PARENT_ID}; SAMPLED=0)

    ENV[XRay::LambdaContext::TRACE_ID_ENV_VAR] = header_str
    entity_2 = context.current_entity
    refute_equal(entity, entity_2)
    assert_instance_of(XRay::FacadeSegment, entity_2)
    assert_equal(trace_id_2, entity_2.trace_id)
    assert_equal(PARENT_ID, entity_2.to_h[:parent_id])
  end

  def test_lambda_emitter_omits_runtime_segments
    emitter = XRay::LambdaEmitter.new
    entity = XRay::Segment.new(name: '127.0.0.1')
    refute( emitter.should_send?(entity: entity ))
  end
  def test_lambda_emitter_sends_other_entities
    emitter = XRay::LambdaEmitter.new
    entity = XRay::Segment.new(name: 'something_else')
    assert( emitter.should_send?(entity: entity ))
  end
  def test_lambda_emitter_send_entity
    config = Struct.new(:udp_ip, :udp_port).new('127.0.0.1',55555)
    listener = UDPSocket.new
    listener.bind(config.udp_ip, config.udp_port)
    emitter = XRay::LambdaEmitter.new
    emitter.daemon_config=config
    entity = XRay::Segment.new(name: 'should_send')
    entity.sampled = true
    emitter.send_entity(entity: entity)
    data = listener.recvfrom_nonblock(65535)
    recieved_entity = data[0].split("\n")[1]
    assert_equal(entity.to_json, recieved_entity)
    listener.close
  end

  def test_lambda_stream_threshold_is_one
    streamer = XRay::LambdaStreamer.new
    assert_equal(1, streamer.stream_threshold)
  end
end
