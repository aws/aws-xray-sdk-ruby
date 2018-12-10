require_relative '../test_helper'
require 'aws-xray-sdk/facets/rack'
require 'rack'

class TestFacetRack < Minitest::Test

  ENV_WITH_QUERY_STRING = {
    "GATEWAY_INTERFACE" => "CGI/1.1",
    "PATH_INFO" => "/index.html",
    "QUERY_STRING" => "",
    "REMOTE_ADDR" => "::1",
    "REMOTE_HOST" => "localhost",
    "REQUEST_METHOD" => "GET",
    "REQUEST_URI" => "http://localhost:3000/index.html?foo=bar",
    "SCRIPT_NAME" => "",
    "SERVER_NAME" => "localhost",
    "SERVER_PORT" => "3000",
    "SERVER_PROTOCOL" => "HTTP/1.1",
    "SERVER_SOFTWARE" => "WEBrick/1.3.1 (Ruby/2.0.0/2013-11-22)",
    "HTTP_HOST" => "localhost:3000",
    "HTTP_USER_AGENT" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.9; rv:26.0) Gecko/20100101 Firefox/26.0",
    "HTTP_ACCEPT" => "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
    "HTTP_ACCEPT_LANGUAGE" => "zh-tw,zh;q=0.8,en-us;q=0.5,en;q=0.3",
    "HTTP_ACCEPT_ENCODING" => "gzip, deflate",
    "HTTP_COOKIE" => "jsonrpc.session=3iqp3ydRwFyqjcfO0GT2bzUh.bacc2786c7a81df0d0e950bec8fa1a9b1ba0bb61",
    "HTTP_CONNECTION" => "keep-alive",
    "HTTP_CACHE_CONTROL" => "max-age=0",
    "rack.version" => [1, 2],
    "rack.multithread" => true,
    "rack.multiprocess" => false,
    "rack.run_once" => false,
    "rack.url_scheme" => "http",
    "HTTP_VERSION" => "HTTP/1.1",
    "REQUEST_PATH" => "/index.html"
  }.freeze

  @@recorder = XRay::Recorder.new
  config = {
    name: "rack_test",
    emitter: XRay::TestHelper::StubbedEmitter.new,
    sampler: XRay::TestHelper::StubbedDefaultSampler.new
  }
  @@recorder.configure(config)

  @@app = Minitest::Mock.new
  def @@app.call(env)
    return 200, {}, ""
  end

  def setup
    @@recorder.context.clear!
    @@recorder.emitter.clear
  end

  def teardown
    @@recorder.context.clear!
    @@recorder.emitter.clear
  end

  def test_rack_http_url_excludes_query_string
    middleware = XRay::Rack::Middleware.new(@@app, :recorder => @@recorder)
    middleware.call ENV_WITH_QUERY_STRING
    segment = @@recorder.emitter.entities[0]
    assert_equal "http://localhost:3000/index.html", segment.http_request[:url]
  end

  def test_rack_returns_xray_header
    middleware = XRay::Rack::Middleware.new(@@app, :recorder => @@recorder)
    _, headers, _ = middleware.call ENV_WITH_QUERY_STRING
    assert_equal true, headers.has_key?(XRay::Facets::Helper::TRACE_HEADER)
    assert_match /^Root=/, headers[XRay::Facets::Helper::TRACE_HEADER]
    refute_match /ParentId=/, headers[XRay::Facets::Helper::TRACE_HEADER]
    refute_match /Sampled=/, headers[XRay::Facets::Helper::TRACE_HEADER]
  end

end
