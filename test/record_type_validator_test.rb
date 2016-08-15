require 'test_helper'
require 'smart_proxy_dhcp_infoblox/record_type_validator'

class RecordTypeValidatorTest < Test::Unit::TestCase
  def setup
    @validator = ::Proxy::DHCP::Infoblox::RecordTypeValidator.new(:dhcp_infoblox, :record_type, nil, nil)
  end

  def test_should_pass_when_record_type_is_host
    assert @validator.validate!(:record_type => 'host')
  end

  def test_should_pass_when_record_type_is_fixedaddress
    assert @validator.validate!(:record_type => 'fixedaddress')
  end

  def test_should_raise_exception_when_record_type_is_unrecognised
    assert_raises(::Proxy::Error::ConfigurationError) { @validator.validate!(:record_type => '') }
  end
end
