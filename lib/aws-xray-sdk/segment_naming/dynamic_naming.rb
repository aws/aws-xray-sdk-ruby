require 'aws-xray-sdk/segment_naming/segment_naming'
require 'aws-xray-sdk/search_pattern'

module XRay
  # Decides what name to use on a segment generated from an incoming request.
  # This default naming takes the host name and compares it to a pre-defined pattern.
  # If the host name matches that pattern, it returns the host name, otherwise
  # it returns the fallback name. The host name usually comes from the incoming
  # request's headers.
  class DynamicNaming
    include SegmentNaming

    # @param [String] fallback The fallback name used when there is no match
    #   between host name and specified pattern.
    def initialize(fallback:)
      @fallback = fallback
    end

    # @param [String] host The host name fetched from the incoming request's header.
    def provide_name(host:)
      # use fallback name when either the pattern or host name is unavailable.
      return fallback unless pattern && !pattern.empty? && host && !host.empty?
      SearchPattern.wildcard_match?(pattern: pattern, text: host) ? host : fallback
    end
  end
end
