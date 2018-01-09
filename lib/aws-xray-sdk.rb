require 'aws-xray-sdk/recorder'

module XRay
  @recorder = Recorder.new

  # providing the default global recorder
  def self.recorder
    @recorder
  end
end
