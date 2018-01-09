require 'aws-xray-sdk/streaming/streamer'
require 'aws-xray-sdk/logger'

module XRay
  # The default streamer use subsegment count as the threshold
  # for performance reasons and it streams out subtrees
  # where all the nodes in it are completed.
  class DefaultStreamer
    include Streamer
    include Logging

    def initialize
      @stream_threshold = 50
    end

    # @param [Segment] segment Check if the provided segment exceeds
    #   the threshold to stream.
    def eligible?(segment:)
      # only get subsegments to stream from sampled segments.
      segment && segment.sampled && segment.subsegment_size >= stream_threshold
    end

    # @param [Segment] root The target segment to stream subsegments from.
    # @param [Emitter] emitter The emitter employed to send data to the daemon.
    def stream_subsegments(root:, emitter:)
      children = root.subsegments
      children_ready = []

      unless children.empty?
        # Collect ready subtrees from root.
        children.each do |child|
          children_ready << child if stream_subsegments root: child, emitter: emitter
        end
      end

      # If this subtree is ready, go back to the root's parent
      # to try to find a bigger subtree
      return true if children_ready.length == children.length && root.closed?
      # Otherwise this subtree has at least one non-ready node.
      # Only stream its ready child subtrees.
      children_ready.each do |child|
        root.remove_subsegment subsegment: child
        emitter.send_entity entity: child
      end
      # Return false so this node won't be added to its parent's ready children.
      false
    end

    # @return [Integer] The maximum number of subsegments a segment
    #   can hold before streaming.
    attr_accessor :stream_threshold
  end
end
