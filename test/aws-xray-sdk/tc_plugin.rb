require 'webmock/minitest'
require 'aws-xray-sdk/plugins/elastic_beanstalk'
require 'aws-xray-sdk/plugins/ec2'
require 'aws-xray-sdk/plugins/ecs'
require 'aws-xray-sdk/recorder'

# test AWS service plugins pass through
class TestPlugins < Minitest::Test
  def test_origin_all_set
    assert XRay::Plugins::ElasticBeanstalk::ORIGIN
    assert XRay::Plugins::EC2::ORIGIN
    assert XRay::Plugins::ECS::ORIGIN
  end

  # all plugins should have method 'aws' and it should not break
  # when running on any machine.
  def test_get_runtime_context
    XRay::Plugins::ElasticBeanstalk.aws
    stub_request(:any, XRay::Plugins::EC2::ID_ADDR).to_raise(StandardError)
    stub_request(:any, XRay::Plugins::EC2::AZ_ADDR).to_raise(StandardError)
    XRay::Plugins::EC2.aws
    XRay::Plugins::ECS.aws
    WebMock.reset!
  end

  def test_mocked_ec2_metadata
    instance_id = "abc"
    az = "us-east-1a"
    stub_request(:any, XRay::Plugins::EC2::ID_ADDR)
      .to_return(body: instance_id, status: 200)
    stub_request(:any, XRay::Plugins::EC2::AZ_ADDR)
      .to_return(body: az, status: 200)
    expected = {
      ec2: {
        instance_id: instance_id,
        avaliablity_zone: az
      }
    }
    assert expected, XRay::Plugins::EC2.aws
    WebMock.reset!
  end
end
