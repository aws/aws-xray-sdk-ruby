require_relative '../test_helper'
require 'webmock/minitest'
require 'aws-xray-sdk/recorder'
require 'aws-xray-sdk/exceptions'
require 'aws-xray-sdk/version'
require 'aws-xray-sdk/plugins/ec2'

# Test global X-Ray recorder
class TestRecorder < Minitest::Test
  @@recorder = XRay::Recorder.new
  @@recorder.config.sampling = false
  @@recorder.config.emitter = XRay::TestHelper::StubbedEmitter.new

  def setup
    @@recorder.context.clear!
    @@recorder.emitter.clear
  end

  def teardown
    @@recorder.context.clear!
    @@recorder.emitter.clear
  end

  def test_get_segment
    segment = @@recorder.begin_segment name: name
    assert_equal segment, @@recorder.current_segment
    assert segment.sampled
  end

  def test_get_subsegment
    segment = @@recorder.begin_segment name: name
    subsegment = @@recorder.begin_subsegment name: name
    assert_equal segment, @@recorder.current_segment
    assert_equal subsegment, @@recorder.current_subsegment
    assert segment.sampled
  end

  def test_send_segment
    segment = @@recorder.begin_segment name: name
    @@recorder.end_segment
    assert_equal segment, @@recorder.emitter.entities[0]
    assert_raises XRay::ContextMissingError do
      @@recorder.current_segment
    end
  end

  def test_subsegment_capture
    segment = @@recorder.begin_segment name
    at = { k: 'v' }
    @@recorder.capture('compute') do |subsegment|
      subsegment.annotations.update at
    end
    subsegment = segment.subsegments[0]
    assert_equal at, subsegment.annotations.to_h
    assert subsegment.closed?
  end

  def test_nested_subsegments
    @@recorder.begin_segment name
    subsegment1 = @@recorder.begin_subsegment name
    @@recorder.begin_subsegment name
    @@recorder.begin_subsegment name
    @@recorder.end_subsegment
    @@recorder.end_subsegment
    assert_equal subsegment1, @@recorder.current_subsegment
  end

  def test_subsegments_streaming
    threshold = @@recorder.streamer.stream_threshold
    segment = @@recorder.begin_segment name
    (threshold + 1).times do |i|
      @@recorder.begin_subsegment i.to_s
    end
    (threshold + 1).times do
      @@recorder.end_subsegment
    end
    assert_equal 2, @@recorder.emitter.entities.count
    # segment should not be prematurely sent in this case
    refute @@recorder.emitter.entities.include?(segment)
    @@recorder.end_segment

    assert_equal 3, @@recorder.emitter.entities.count
    assert_equal segment, @@recorder.emitter.entities[2]
  end

  def test_sampled_block
    @@recorder.begin_segment name
    x = 0
    @@recorder.sampled? do
      x = 1
    end
    assert_equal 1, x
    assert @@recorder.sampled?
  end

  def test_sampling_segments
    recorder = XRay::Recorder.new
    config = {
      sampling: true,
      emitter: XRay::TestHelper::StubbedEmitter.new,
      sampler: XRay::TestHelper::StubbedDefaultSampler.new
    }
    recorder.configure(config)

    segment = recorder.begin_segment('name')
    assert segment.sampled
    recorder.context.clear!
  end

  def test_add_annotation
    segment = @@recorder.begin_segment name
    @@recorder.annotations[:k] = 1
    assert_equal 1, segment.annotations.to_h[:k]

    subsegment = @@recorder.begin_subsegment name, segment: segment
    @@recorder.annotations[:k2] = 2
    assert_equal 2, subsegment.annotations.to_h[:k2]
    refute segment.annotations.to_h.key?(:k2)
  end

  def test_add_metadata
    segment = @@recorder.begin_segment name
    @@recorder.metadata[:k] = 1
    assert_equal 1, segment.to_h[:metadata][:default][:k]
    subsegment = @@recorder.begin_subsegment name, segment: segment
    @@recorder.metadata(namespace: :ns)[:k] = 1
    @@recorder.metadata(namespace: :ns).update k2: 2
    assert_equal 1, subsegment.to_h[:metadata][:ns][:k]
    assert_equal 2, subsegment.to_h[:metadata][:ns][:k2]
  end

  def test_thread_infection
    segment = @@recorder.begin_segment name
    thread = Thread.new {
      @@recorder.inject_context segment do
        @@recorder.begin_subsegment 'my_sub'
        @@recorder.end_subsegment
      end
    }
    thread.join
    @@recorder.end_segment

    sent_entity = @@recorder.emitter.entities[0]
    assert_equal segment, sent_entity
    subsegment = sent_entity.subsegments[0]
    assert_equal 'my_sub', subsegment.name
    assert_equal segment.id, subsegment.parent.id
  end

  def test_xray_metadata
    segment = @@recorder.begin_segment name
    xray_meta = segment.to_h[:aws][:xray]
    assert_equal 'X-Ray for Ruby', xray_meta[:sdk]
    assert_equal XRay::VERSION, xray_meta[:sdk_version]

    service_meta = segment.to_h[:service]
    assert service_meta[:runtime]
    assert service_meta[:runtime_version]
  end

  def test_plugins_runtime_context
    dummy_json = '{\"availabilityZone\" : \"us-east-2a\", \"imageId\" : \"ami-03cca83dd001d4666\",
                  \"instanceId\" : \"i-07a181803de94c666\", \"instanceType\" : \"t3.xlarge\"}'

    stub_request(:put, 'http://169.254.169.254/latest/api/token')
      .to_return(status: 200, body: 'some_token', headers: {})

    stub_request(:get, 'http://169.254.169.254/latest/dynamic/instance-identity/document')
      .to_return(status: 200, body: dummy_json, headers: {})

    recorder = XRay::Recorder.new
    config = {
      sampling: false,
      emitter: XRay::TestHelper::StubbedEmitter.new,
      plugins: %I[ecs ec2]
    }

    recorder.configure(config)
    segment = recorder.begin_segment name

    aws_meta = segment.to_h[:aws]
    assert aws_meta[:ecs]
    assert segment.origin

    WebMock.reset!
  end

  def test_context_missing_passthrough
    recorder = XRay::Recorder.new
    config = {
      sampling: false,
      context_missing: 'LOG_ERROR',
      emitter: XRay::TestHelper::StubbedEmitter.new
    }
    recorder.configure(config)

    recorder.annotations[:k] = 1
    recorder.sampled? do
      recorder.annotations.update k2: 2
      recorder.metadata.update k3: 3
    end
    recorder.metadata[:foo] = 'bar'

    v = recorder.capture(name) do |subsegment|
      subsegment.annotations[:k] = '1'
      1
    end

    assert_equal 1, v
    assert_nil recorder.emitter.entities
  end
end
