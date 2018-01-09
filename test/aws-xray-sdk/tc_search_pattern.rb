require 'aws-xray-sdk/search_pattern'

# Test wildcard matching
class TestSearchPattern < Minitest::Test
  def test_corner_case
    assert XRay::SearchPattern.wildcard_match? pattern: '*', text: ''
    assert XRay::SearchPattern.wildcard_match? pattern: '', text: ''
    refute XRay::SearchPattern.wildcard_match? pattern: '', text: 'a'
    refute XRay::SearchPattern.wildcard_match? pattern: '*', text: nil
    refute XRay::SearchPattern.wildcard_match? pattern: nil, text: ''
    refute XRay::SearchPattern.wildcard_match? pattern: nil, text: nil
  end

  def test_no_special_character
    pattern = 'test'
    assert XRay::SearchPattern.wildcard_match? pattern: pattern, text: pattern
    refute XRay::SearchPattern.wildcard_match? pattern: pattern, text: "a#{pattern}"
    refute XRay::SearchPattern.wildcard_match? pattern: pattern, text: "#{pattern}a"
  end

  def test_star
    assert XRay::SearchPattern.wildcard_match? pattern: '*', text: 'test'
    assert XRay::SearchPattern.wildcard_match? pattern: 'www.*', text: 'www.test.com'
    assert XRay::SearchPattern.wildcard_match? pattern: '*.com', text: 'test.com'
    assert XRay::SearchPattern.wildcard_match? pattern: 'www.*.com', text: 'www.test.com'
    assert XRay::SearchPattern.wildcard_match? pattern: '*test.*', text: 'www.test.org'
  end

  def test_question_mark
    assert XRay::SearchPattern.wildcard_match? pattern: 'te?t', text: 'test'
    assert XRay::SearchPattern.wildcard_match? pattern: '??st', text: 'test'
    assert XRay::SearchPattern.wildcard_match? pattern: 'te??', text: 'test'
    refute XRay::SearchPattern.wildcard_match? pattern: 'te?t', text: 'tet'
  end

  def test_mixed_characters
    assert XRay::SearchPattern.wildcard_match? pattern: '*test?.*', text: 'www.test3.com'
    refute XRay::SearchPattern.wildcard_match? pattern: '*test?.*', text: 'www.test.com'
  end
end
