require 'aws-xray-sdk/sampling/local/reservoir'
require 'aws-xray-sdk/sampling/local/sampler'
require 'aws-xray-sdk/sampling/local/sampling_rule'
require 'aws-xray-sdk/exceptions'

# Test sampling models and the default sampler
class TestSampling < Minitest::Test
  VALID_RULE_DEF = {
    fixed_target: 1,
    rate:         0.5,
    host: '*',
    url_path:     '*/ping',
    http_method:  'PUT'
  }.freeze

  def test_reservoir_pass_through
    reservoir = XRay::LocalReservoir.new traces_per_sec: 1
    assert reservoir.take
    reservoir2 = XRay::LocalReservoir.new
    refute reservoir2.take
  end

  def test_simple_single_rule
    rule = XRay::LocalSamplingRule.new rule_definition: VALID_RULE_DEF

    assert_equal 1, rule.fixed_target
    assert_equal 0.5, rule.rate
    assert_equal '*', rule.host
    assert_equal '*/ping', rule.path
    assert_equal 'PUT', rule.method
    assert rule.reservoir.take
  end

  def test_rule_request_matching
    rule = XRay::LocalSamplingRule.new rule_definition: VALID_RULE_DEF

    req1 = { host: nil, url_path: '/ping', http_method: 'put' }
    req2 = { host: 'a', url_path: nil, http_method: 'put' }
    req3 = { host: 'a', url_path: '/ping', http_method: nil }
    req4 = { host: 'a', url_path: '/ping', http_method: 'PUT' }
    req5 = { host: 'a', url_path: '/sping', http_method: 'PUT' }
    assert rule.applies?(req1)
    assert rule.applies?(req2)
    assert rule.applies?(req3)
    assert rule.applies?(req4)
    refute rule.applies?(req5)
  end

  def test_invalid_single_rule
    # missing path
    rule_def1 = {
      fixed_target: 1,
      rate:         0.5,
      host: '*',
      http_method:  'GET'
    }
    assert_raises XRay::InvalidSamplingConfigError do
      XRay::LocalSamplingRule.new rule_definition: rule_def1
    end
    # extra field for default rule
    rule_def2 = {
      fixed_target: 1,
      rate:         0.5,
      host: '*'
    }
    assert_raises XRay::InvalidSamplingConfigError do
      XRay::LocalSamplingRule.new rule_definition: rule_def2, default: true
    end
    # invalid value
    rule_def3 = {
      fixed_target: 1,
      rate:         -0.5
    }
    assert_raises XRay::InvalidSamplingConfigError do
      XRay::LocalSamplingRule.new rule_definition: rule_def3, default: true
    end
  end

  EXAMPLE_CONFIG = {
    version: 2,
    rules: [
      {
        description: 'Player moves.',
        host: '*',
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

  def test_local_sampler
    sampler = XRay::LocalSampler.new
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
    sampler = XRay::LocalSampler.new
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
