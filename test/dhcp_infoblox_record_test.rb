require 'test_helper'
require 'dns/dns_plugin'
require 'smart_proxy_dhcp_infoblox/dhcp_infoblox_plugin'
require 'smart_proxy_dhcp_infoblox/dhcp_infoblox_main'


class InfobloxRecordTest < Test::Unit::TestCase

  def test_default_settings
    Proxy::Dns::Infoblox::Plugin.load_test_settings({})
    assert_equal "default_value", Proxy::Dns::Nsupdate::Plugin.settings.required_setting
    assert_equal "/must/exist", Proxy::Dns::Nsupdate::Plugin.settings.required_path
  end

  def test_initialized_correctly
    Proxy::Dns::Infoblox::Plugin.load_test_settings(:example_setting => 'a_value',
                                                          :required_setting => 'required_setting',
                                                          :optional_path => '/some/path',
                                                          :required_path => '/required/path')

    assert_equal 'a_value', klass.new.example_setting
    assert_equal 'required_value', klass.new.required_setting
    assert_equal '/some/path', klass.new.optional_path
    assert_equal '/required/path', klass.new.required_path
  end

  # Test that a missing :example_setting throws an error
  # Test A record creation
  def test_create_a
    # Use mocha to expect any calls to backend services to prevent creating real records
    #   MyService.expects(:create).with(:ip => '10.1.1.1', :name => 'test.example.com').returns(true)

    assert klass.new.create_a_record('test.example.com', '10.1.1.1')
  end

  # Test A record creation fails if the record exists
  def test_create_a_conflict
    # Use mocha to expect any calls to backend services to prevent creating real records
    #   MyService.expects(:create).with(:ip => '10.1.1.1', :name => 'test.example.com').returns(false)

    assert_raise(Proxy::Dns::Collision) { klass.new.create_a_record('test.example.com', '10.1.1.1') }
  end

  # Test PTR record creation
  def test_create_ptr
    # Use mocha to expect any calls to backend services to prevent creating real records
    #   MyService.expects(:create_reverse).with(:ip => '10.1.1.1', :name => 'test.example.com').returns(true)

    assert klass.new.create_ptr_record('test.example.com', '10.1.1.1')
  end

  # Test PTR record creation fails if the record exists
  def test_create_ptr_conflict
    # Use mocha to expect any calls to backend services to prevent creating real records
    #   MyService.expects(:create_reverse).with(:ip => '10.1.1.1', :name => 'test.example.com').returns(false)

    assert_raise(Proxy::Dns::Collision) { klass.new.create_ptr_record('test.example.com', '10.1.1.1') }
  end

  # Test A record removal
  def test_remove_a
    # Use mocha to expect any calls to backend services to prevent deleting real records
    #   MyService.expects(:delete).with(:name => 'test.example.com').returns(true)

    assert klass.new.remove_a_record('test.example.com')
  end

  # Test A record removal fails if the record doesn't exist
  def test_remove_a_not_found
    # Use mocha to expect any calls to backend services to prevent deleting real records
    #   MyService.expects(:delete).with(:name => 'test.example.com').returns(false)

    assert_raise(Proxy::Dns::NotFound) { assert klass.new.remove_a_record('test.example.com') }
  end

  # Test PTR record removal
  def test_remove_ptr
    # Use mocha to expect any calls to backend services to prevent deleting real records
    #   MyService.expects(:delete).with(:ip => '10.1.1.1').returns(true)

    assert klass.new.remove_ptr_record('1.1.1.10.in-addr.arpa')
  end

  # Test PTR record removal fails if the record doesn't exist
  def test_remove_ptr_not_found
    # Use mocha to expect any calls to backend services to prevent deleting real records
    #   MyService.expects(:delete).with(:ip => '10.1.1.1').returns(false)

    assert_raise(Proxy::Dns::NotFound) { assert klass.new.remove_ptr_record('1.1.1.10.in-addr.arpa') }
  end

  def klass
    Proxy::Dns::Infoblox::Record
  end
end
