lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'aws-xray-sdk/version'

Gem::Specification.new do |spec|
  spec.name          = 'aws-xray-sdk'
  spec.version       = XRay::VERSION
  spec.author        = 'Amazon Web Services'
  spec.email         = 'aws-xray-ruby@amazon.com'

  spec.summary       = 'AWS X-Ray SDK for Ruby'
  spec.description   = 'The AWS X-Ray SDK for Ruby enables Ruby developers to record and emit information from within their applications to the AWS X-Ray service.'
  spec.homepage      = 'https://github.com/aws/aws-xray-sdk-ruby'

  spec.required_ruby_version = '>= 2.3.6'

  spec.license       = 'Apache-2.0'

  spec.files         = Dir.glob('lib/**/*')
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.add_dependency 'aws-sdk-xray', '~> 1.4.0'
  spec.add_dependency 'multi_json', '~> 1'

  spec.add_development_dependency 'aws-sdk-dynamodb', '~> 1'
  spec.add_development_dependency 'aws-sdk-s3', '~> 1'
  spec.add_development_dependency 'bundler', '~> 2.0'
  spec.add_development_dependency 'minitest', '~> 5.0'
  spec.add_development_dependency 'rack', '~> 2.0'
  spec.add_development_dependency 'rake', '~> 12.0'
  spec.add_development_dependency 'simplecov', '~> 0.15'
  spec.add_development_dependency 'webmock', '~> 3.0'
  spec.add_development_dependency 'yard', '~> 0.9'
end
