require_relative '../test_helper'
require 'aws-xray-sdk/model/segment'
require 'aws-xray-sdk/model/subsegment'
require 'aws-xray-sdk/streaming/default_streamer'

# Subtree streaming test suite
class TestStreaming < Minitest::Test

  def test_segment_eligibility
    segment = XRay::Segment.new name: name
    subsegment = XRay::Subsegment.new name: name, segment: segment
    segment.add_subsegment subsegment: subsegment
    streamer = XRay::DefaultStreamer.new
    streamer.stream_threshold = 1

    refute streamer.eligible? segment: nil
    assert streamer.eligible? segment: segment
  end

  def test_single_subsegment
    segment = XRay::Segment.new name: name
    subsegment = XRay::Subsegment.new name: name, segment: segment
    segment.add_subsegment subsegment: subsegment
    subsegment.close

    streamer = XRay::DefaultStreamer.new
    streamer.stream_threshold = 1
    emitter = XRay::TestHelper::StubbedEmitter.new
    streamer.stream_subsegments root: segment, emitter: emitter
    assert_equal 1, emitter.entities.count
    assert_equal 0, segment.subsegment_size
  end

  # all segment/subsegments has only one child subsegment.
  def test_single_path
    segment = XRay::Segment.new name: name
    subsegment1 = XRay::Subsegment.new name: name, segment: segment
    subsegment2 = XRay::Subsegment.new name: name, segment: segment
    subsegment3 = XRay::Subsegment.new name: name, segment: segment
    segment.add_subsegment subsegment: subsegment1
    subsegment1.add_subsegment subsegment: subsegment2
    subsegment2.add_subsegment subsegment: subsegment3
    subsegment3.close
    subsegment2.close

    streamer = XRay::DefaultStreamer.new
    streamer.stream_threshold = 1
    emitter = XRay::TestHelper::StubbedEmitter.new
    streamer.stream_subsegments root: segment, emitter: emitter

    streamed_out = emitter.entities
    # subtree with root node subsegment2 should be streamed out
    assert_equal 1, streamed_out.count
    assert_equal subsegment2, streamed_out[0]
    assert_equal 1, segment.subsegment_size
    assert_equal subsegment1, segment.subsegments[0]
    # check reference removal
    refute segment.subsegments.include?(subsegment2)
  end

  # root segment has two subtrees eligible to stream
  def test_multi_subtrees
    segment = XRay::Segment.new name: name
    subsegments = []
    4.times do
      subsegments << XRay::Subsegment.new(name: name, segment: segment)
    end
    subsegments[0].add_subsegment subsegment: subsegments[2]
    subsegments[1].add_subsegment subsegment: subsegments[3]
    segment.add_subsegment subsegment: subsegments[0]
    segment.add_subsegment subsegment: subsegments[1]
    subsegments.each &:close

    streamer = XRay::DefaultStreamer.new
    streamer.stream_threshold = 1
    emitter = XRay::TestHelper::StubbedEmitter.new
    streamer.stream_subsegments root: segment, emitter: emitter

    streamed_out = emitter.entities
    # subtree with root node subsegment0 and subsegment1 should be streamed out
    assert_equal 2, streamed_out.count
    assert streamed_out.include?(subsegments[0])
    assert streamed_out.include?(subsegments[1])
    assert_equal 0, segment.subsegment_size
    # check reference removal
    assert segment.subsegments.empty?
  end
end
