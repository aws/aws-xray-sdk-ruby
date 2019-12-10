require_relative '../test_helper'
require 'aws-xray-sdk/facets/net_http'

class TestFacetNetHttp < Minitest::Test

  def setup
    ENV['AWS_LAMBDA_RUNTIME_API'] = 'localhost:3000'
  end

  def teardown
    ENV.delete('AWS_LAMBDA_RUNTIME_API')
  end

  def test_lambda_runtime_request_true
    http = Net::HTTP.new('localhost',3000)
    assert http.lambda_runtime_request?
  end

  def test_lambda_runtime_request_false
    http = Net::HTTP.new('www.example.com',3000)
    refute http.lambda_runtime_request?
  end

  def test_lambda_runtime_request_nil_env
    ENV.delete('AWS_LAMBDA_RUNTIME_API')
    refute ENV['AWS_LAMBDA_RUNTIME_API']
    http = Net::HTTP.new('www.example.com',3000)
    refute http.lambda_runtime_request?
  end
end
