source 'https://rubygems.org'
gemspec

gem 'webrick'

group :rubocop do
  gem 'rubocop', '~> 1.28.0'
  gem 'rubocop-performance'
  gem 'rubocop-rake'
end

group :test do
  gem 'ci_reporter_test_unit'
  gem 'concurrent-ruby', '~> 1.0', require: 'concurrent'
  gem 'mocha'
  gem 'rack-test'
  gem 'rake'
  gem 'smart_proxy', :github => 'theforeman/smart-proxy', :branch => 'develop'
  gem 'test-unit'
end
