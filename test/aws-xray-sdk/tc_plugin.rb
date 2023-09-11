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
    stub_request(:any, XRay::Plugins::EC2::METADATA_BASE_URL + '/api/token')
      .to_raise(StandardError)
    stub_request(:any, XRay::Plugins::EC2::METADATA_BASE_URL + '/dynamic/instance-identity/document')
      .to_raise(StandardError)
    stub_request(:any, XRay::Plugins::ECS::METADATA_BASE_URL + '/api/token')
      .to_raise(StandardError)
    stub_request(:any, XRay::Plugins::ECS::METADATA_BASE_URL + '/dynamic/instance-identity/document')
      .to_raise(StandardError)
    XRay::Plugins::EC2.aws
    XRay::Plugins::ECS.aws
    WebMock.reset!
  end

  def test_ec2_metadata_v2_successful
    dummy_json = '{\"availabilityZone\" : \"us-east-2a\", \"imageId\" : \"ami-03cca83dd001d4666\",
                  \"instanceId\" : \"i-07a181803de94c666\", \"instanceType\" : \"t3.xlarge\"}'

    stub_request(:put, XRay::Plugins::EC2::METADATA_BASE_URL + '/api/token')
      .to_return(status: 200, body: 'some_token', headers: {})

    stub_request(:get, XRay::Plugins::EC2::METADATA_BASE_URL + '/dynamic/instance-identity/document')
      .to_return(status: 200, body: dummy_json, headers: {})

    expected = {
      ec2: {
        instance_id: 'i-07a181803de94c666',
        availability_zone: 'us-east-2a',
        instance_type: 't3.xlarge',
        ami_id: 'ami-03cca83dd001d4666'
      }
    }
    assert expected, XRay::Plugins::EC2.aws
    WebMock.reset!
  end

  def test_ec2_metadata_v1_successful
    dummy_json = '{\"availabilityZone\" : \"cn-north-1a\", \"imageId\" : \"ami-03cca83dd001d4111\",
                  \"instanceId\" : \"i-07a181803de94c111\", \"instanceType\" : \"t2.xlarge\"}'

    stub_request(:put, XRay::Plugins::EC2::METADATA_BASE_URL + '/api/token')
      .to_raise(StandardError)

    stub_request(:get, XRay::Plugins::EC2::METADATA_BASE_URL + '/dynamic/instance-identity/document')
      .to_return(status: 200, body: dummy_json, headers: {})

    expected = {
      ec2: {
        instance_id: 'i-07a181803de94c111',
        availability_zone: 'cn-north-1a',
        instance_type: 't2.xlarge',
        ami_id: 'ami-03cca83dd001d4111'
      }
    }
    assert expected, XRay::Plugins::EC2.aws
    WebMock.reset!
  end
  
  def test_ec2_metadata_fail
    stub_request(:put, XRay::Plugins::EC2::METADATA_BASE_URL + '/api/token')
      .to_raise(StandardError)

    stub_request(:get, XRay::Plugins::EC2::METADATA_BASE_URL + '/dynamic/instance-identity/document')
      .to_raise(StandardError)

    expected = {}
    assert expected, XRay::Plugins::EC2.aws
    WebMock.reset!
  end

  def test_get_runtime_context
    XRay::Plugins::ElasticBeanstalk.aws
    stub_request(:any, XRay::Plugins::EC2::METADATA_BASE_URL + '/api/token')
      .to_raise(StandardError)
    stub_request(:any, XRay::Plugins::EC2::METADATA_BASE_URL + '/dynamic/instance-identity/document')
      .to_raise(StandardError)
    stub_request(:any, XRay::Plugins::ECS::METADATA_BASE_URL + '/api/token')
      .to_raise(StandardError)
    stub_request(:any, XRay::Plugins::ECS::METADATA_BASE_URL + '/dynamic/instance-identity/document')
      .to_raise(StandardError)
    XRay::Plugins::EC2.aws
    XRay::Plugins::ECS.aws
    WebMock.reset!
  end

  def test_ecs_metadata_v2_successful
    dummy_json = '{\"availabilityZone\" : \"us-east-2a\", \"imageId\" : \"ami-03cca83dd001d4666\",
                  \"instanceId\" : \"i-07a181803de94c666\", \"instanceType\" : \"t3.xlarge\"}'

    stub_request(:put, XRay::Plugins::ECS::METADATA_BASE_URL + '/api/token')
      .to_return(status: 200, body: 'some_token', headers: {})

    stub_request(:get, XRay::Plugins::ECS::METADATA_BASE_URL + '/dynamic/instance-identity/document')
      .to_return(status: 200, body: dummy_json, headers: {})

    expected = {
      ec2: {
        instance_id: 'i-07a181803de94c666',
        availability_zone: 'us-east-2a',
        instance_type: 't3.xlarge',
        ami_id: 'ami-03cca83dd001d4666'
      }
    }
    assert expected, XRay::Plugins::ECS.aws
    WebMock.reset!
  end

  def test_ecs_metadata_v1_successful
    dummy_json = '{\"availabilityZone\" : \"cn-north-1a\", \"imageId\" : \"ami-03cca83dd001d4111\",
                  \"instanceId\" : \"i-07a181803de94c111\", \"instanceType\" : \"t2.xlarge\"}'

    stub_request(:put, XRay::Plugins::ECS::METADATA_BASE_URL + '/api/token')
      .to_raise(StandardError)

    stub_request(:get, XRay::Plugins::ECS::METADATA_BASE_URL + '/dynamic/instance-identity/document')
      .to_return(status: 200, body: dummy_json, headers: {})

    expected = {
      ec2: {
        instance_id: 'i-07a181803de94c111',
        availability_zone: 'cn-north-1a',
        instance_type: 't2.xlarge',
        ami_id: 'ami-03cca83dd001d4111'
      }
    }
    assert expected, XRay::Plugins::ECS.aws
    WebMock.reset!
  end
  
  def test_ecs_metadata_fail
    stub_request(:put, XRay::Plugins::ECS::METADATA_BASE_URL + '/api/token')
      .to_raise(StandardError)

    stub_request(:get, XRay::Plugins::ECS::METADATA_BASE_URL + '/dynamic/instance-identity/document')
      .to_raise(StandardError)

    expected = {}
    assert expected, XRay::Plugins::ECS.aws
    WebMock.reset!
  end
end
