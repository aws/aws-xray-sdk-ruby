require 'aws-xray-sdk/exceptions'

module XRay
  # Patching external libraries/frameworks to be traced by X-Ray recorder.
  module Patcher
    # @param [Array] targets A list of libraries/frameworks to patch.
    def patch(targets)
      targets.each do |l|
        case l
        when :net_http
          require 'aws-xray-sdk/facets/net_http'
        when :aws_sdk
          require 'aws-xray-sdk/facets/aws_sdk'
          XRay::AwsSDKPatcher.patch
        else
          raise UnsupportedPatchingTargetError.new(%(#{l} is not supported by X-Ray SDK.))
        end
      end
    end
  end
end
