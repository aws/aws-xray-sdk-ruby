require 'aws-xray-sdk/segment_naming/dynamic_naming'

# Test dynamic naming suite
class TestDynamicNaming < Minitest::Test
  def test_no_pattern_specified
    fallback = 'test'
    naming = XRay::DynamicNaming.new fallback: fallback
    assert_equal fallback, naming.provide_name(host: 'example.com')
    assert_equal fallback, naming.provide_name(host: nil)
    assert_equal fallback, naming.provide_name(host: '')
  end

  def test_hostname_unavailable
    fallback = 'test'
    naming = XRay::DynamicNaming.new fallback: fallback
    naming.pattern = '*'
    assert_equal fallback, naming.provide_name(host: nil)
    assert_equal fallback, naming.provide_name(host: '')
  end

  def test_pattern_matching
    fallback = 'test'
    naming = XRay::DynamicNaming.new fallback: fallback
    naming.pattern = '*mydomain*'
    host = 'www.mydomain.com'
    assert_equal host, naming.provide_name(host: host)
    refute_equal host, naming.provide_name(host: '127.0.0.1')
    assert_equal fallback, naming.provide_name(host: '127.0.0.1')
  end
end
