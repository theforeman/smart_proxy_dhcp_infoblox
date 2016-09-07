source 'https://rubygems.org'
gemspec

gem 'infoblox', '>= 0.4.1'
if RUBY_VERSION < '2.0.0'
  gem 'json', '< 2.0.0', :require => false
end

group :development do
  if RUBY_VERSION < '1.9.3'
    gem 'rake', '< 11'
  else
    gem 'rake'
    gem 'test-unit'
  end
  gem 'mocha'
  gem 'smart_proxy', :github => 'theforeman/smart-proxy', :branch => 'develop'
end
