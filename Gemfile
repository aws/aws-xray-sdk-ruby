source 'https://rubygems.org'

if ENV["TEST_DISTRIBUTION"]
  gem 'aws-xray-sdk'
  gem 'minitest'
  gem 'rake'
  gem 'yard'
else
  gemspec
end

# These are here instead of the gemspec so that they can be properly conditionalized by platform.
gem 'oj', platform: :mri
gem 'jrjackson', platform: :jruby
