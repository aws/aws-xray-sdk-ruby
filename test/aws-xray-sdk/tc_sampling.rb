require 'aws-xray-sdk/sampling/sampling_rule'
require 'aws-xray-sdk/sampling/reservoir'
require 'aws-xray-sdk/sampling/default_sampler'
require 'aws-xray-sdk/exceptions'

# Test sampling models and the default sampler
class TestSampling < Minitest::Test
  VALID_RULE_DEF = {
    fixed_target: 1,
    rate:         0.5,
    service_name: '*',
    url_path:     '*/ping',
    http_method:  'PUT'
  }.freeze

  def test_reservoir_pass_through
    reservoir = XRay::Reservoir.new traces_per_sec: 1
    assert reservoir.take
    reservoir2 = XRay::Reservoir.new
    refute reservoir2.take
  end

  def test_simple_single_rule
    rule = XRay::SamplingRule.new rule_definition: VALID_RULE_DEF

    assert_equal 1, rule.fixed_target
    assert_equal 0.5, rule.rate
    assert_equal '*', rule.service_name
    assert_equal '*/ping', rule.path
    assert_equal 'PUT', rule.method
    assert rule.reservoir.take
  end

  def test_rule_request_matching
    rule = XRay::SamplingRule.new rule_definition: VALID_RULE_DEF

    assert rule.applies? target_name: nil, target_path: '/ping', target_method: 'put'
    assert rule.applies? target_name: 'a', target_path: nil, target_method: 'put'
    assert rule.applies? target_name: 'a', target_path: '/ping', target_method: nil
    assert rule.applies? target_name: 'a', target_path: '/ping', target_method: 'PUT'
    refute rule.applies? target_name: 'a', target_path: '/sping', target_method: 'PUT'
  end

  def test_invalid_single_rule
    # missing path
    rule_def1 = {
      fixed_target: 1,
      rate:         0.5,
      service_name: '*',
      http_method:  'GET'
    }
    assert_raises XRay::InvalidSamplingConfigError do
      XRay::SamplingRule.new rule_definition: rule_def1
    end
    # extra field for default rule
    rule_def2 = {
      fixed_target: 1,
      rate:         0.5,
      service_name: '*'
    }
    assert_raises XRay::InvalidSamplingConfigError do
      XRay::SamplingRule.new rule_definition: rule_def2, default: true
    end
    # invalid value
    rule_def3 = {
      fixed_target: 1,
      rate:         -0.5
    }
    assert_raises XRay::InvalidSamplingConfigError do
      XRay::SamplingRule.new rule_definition: rule_def3, default: true
    end
  end

  EXAMPLE_CONFIG = {
    version: 1,
    rules: [
      {
        description: 'Player moves.',
        service_name: '*',
        http_method: '*',
        url_path: '*/ping',
        fixed_target: 0,
        rate: 0
      }
    ],
    default: {
      fixed_target: 1,
      rate: 0.1
    }
  }.freeze

  def test_default_sampler
    sampler = XRay::DefaultSampler.new
    assert sampler.sample?
    # should only has default rule
    assert_equal 1, sampler.sampling_rules.count
    sampler.sampling_rules = EXAMPLE_CONFIG
    # now has one extra custom rule
    assert_equal 2, sampler.sampling_rules.count
    # don't sample health checks based on the custom rule
    refute sampler.sample_request? service_name: '*', url_path: '/ping', http_method: 'GET'
  end

  def test_invalid_rules_config
    sampler = XRay::DefaultSampler.new
    config1 = EXAMPLE_CONFIG.merge(version: nil)
    assert_raises XRay::InvalidSamplingConfigError do
      sampler.sampling_rules = config1
    end
    config2 = EXAMPLE_CONFIG.merge(default: nil)
    assert_raises XRay::InvalidSamplingConfigError do
      sampler.sampling_rules = config2
    end
  end
end
