require 'test_helper'
require 'ostruct'
require 'infoblox'
require 'dhcp_common/dhcp_common'
require 'dhcp_common/record/reservation'
require 'smart_proxy_dhcp_infoblox/fixed_address_crud'
require 'smart_proxy_dhcp_infoblox/host_ipv4_address_crud'

module CommoncrudTests
  def test_find_record_using_ip
    @entity.expects(:find).with(@connection, search_condition('ipv4addr' => '192.168.42.1', '_max_results' => 1)).returns([@host])
    assert_equal @reservation, @crud.find_record_by_ip('192.168.42.0/24', '192.168.42.1')
  end

  def test_find_record_using_ip_returns_nil_if_record_not_found
    @entity.expects(:find).with(@connection, search_condition('ipv4addr' => '192.168.42.1', '_max_results' => 1)).returns([])
    assert_nil @crud.find_record_by_ip('192.168.42.0/24', '192.168.42.1')
  end

  def test_find_records_using_ip_returns_empty_arrays_if_records_not_found
    @entity.expects(:find).with(@connection, search_condition('ipv4addr' => '192.168.42.1', '_max_results' => 2147483646)).returns([])
    assert @crud.find_records_by_ip('192.168.42.0/24', '192.168.42.1').empty?
  end

  def test_find_records_by_ip_returns_empty_array_when_host_has_no_dhcp_record
    found_record = OpenStruct.new(:name => 'testing',
                                  :ipv4addrs => [OpenStruct.new(:ipv4addr => '192.168.42.1',
                                                                :mac => '00:01:02:03:04:05',
                                                                :configure_for_dhcp => false)])
    @entity.expects(:find).
      with(@connection, search_condition('ipv4addr' => '192.168.42.1', '_max_results' => 2147483646)).returns([found_record])
    assert @crud.find_records_by_ip('192.168.42.0/24', '192.168.42.1').empty?
  end

  def test_find_record_using_mac
    @entity.expects(:find).with(@connection, search_condition('mac' => '00:01:02:03:05:06', '_max_results' => 1)).returns([@host])
    assert_equal @reservation, @crud.find_record_by_mac('192.168.42.0/24', '00:01:02:03:05:06')
  end

  def test_find_record_using_mac_returns_nil_if_record_not_found
    @entity.expects(:find).with(@connection, search_condition('mac' => '00:01:02:03:05:06', '_max_results' => 1)).returns([])
    assert_nil @crud.find_record_by_mac('192.168.42.0/24', '00:01:02:03:05:06')
  end

  def test_find_record_by_ip
    @crud.expects(:find_record_by_ip).with('192.168.42.0/24', '192.168.42.1')
    @crud.find_record('192.168.42.0/24', '192.168.42.1')
  end

  def test_find_record_by_mac
    @crud.expects(:find_record_by_mac).with('192.168.42.0/24', '00:01:02:03:05:06')
    @crud.find_record('192.168.42.0/24', '00:01:02:03:05:06')
  end

  def test_add_record
    @crud.expects(:build_host).with(:ip => @ip, :mac => @mac, :hostname => @hostname).returns(@host)
    @host.expects(:post)

    @crud.add_record(:ip => @ip, :mac => @mac, :hostname => @hostname)
  end

  def test_add_record_with_already_existing_host
    @crud.expects(:build_host).with(:ip => @ip, :mac => @mac, :hostname => @hostname).returns(@host)
    @host.expects(:post).raises(Infoblox::Error.new("IB.Data.Conflict"))
    @crud.expects(:find_hosts).with('ipv4addr' => @ip).returns([@host])

    assert_raises(Proxy::DHCP::AlreadyExists) { @crud.add_record(:ip => @ip, :mac => @mac, :hostname => @hostname) }
  end

  def test_del_record
    @crud.expects(:find_hosts).with('ipv4addr' => @ip).returns([@host])
    @host.expects(:delete)
    @crud.del_record('unused', @reservation)
  end

  def test_del_records_by_ip
    @crud.expects(:find_hosts).with({ 'ipv4addr' => @ip }, 2147483646).returns([@host, @host1])
    @host.expects(:delete)
    @host1.expects(:delete)
    @crud.del_records_by_ip(@ip)
  end

  def test_del_record_by_mac
    @crud.expects(:find_hosts).with('mac' => @mac).returns([@host])
    @host.expects(:delete)
    @crud.del_record_by_mac(@mac)
  end
end

class HostCrudTest < Test::Unit::TestCase
  include CommoncrudTests

  def setup
    @connection = Object.new
    @view = "something"
    @crud = ::Proxy::DHCP::Infoblox::HostIpv4AddressCRUD.new(@connection, @view, 'record_type')

    @entity = ::Infoblox::Host

    @hostname = 'test.test.com'
    @mac = '00:01:02:03:05:06'
    @nextserver = '192.168.42.1'
    @filename = '/tftpboot.img'
    @ip = '192.168.42.1'
    @subnet_ip = '192.168.42.0'

    @host = ::Infoblox::Host.new(
      :name => @hostname,
      :view => @view,
      :ipv4addrs => [{ :ipv4addr => @ip, :mac => @mac, :nextserver => @nextserver, :use_nextserver => true,
                      :bootfile => @filename, :use_bootfile => true, :configure_for_dhcp => true }])
    @host1 = ::Infoblox::Host.new(
      :name => 'another.test.com',
      :view => @view,
      :ipv4addrs => [{ :ipv4addr => @ip, :mac => '00:01:02:03:05:07', :nextserver => @nextserver, :use_nextserver => true,
                      :bootfile => @filename, :use_bootfile => true, :configure_for_dhcp => true }])

    @ipv4address = ::Infoblox::Ipv4address.new(
      :names => [@hostname],
      :ip_address => @ip,
      :mac_address => @mac
    )

    @ipv4address_dnsonly = ::Infoblox::Ipv4address.new(
      :names => ['dnsonly.test.com'],
      :ip_address => '192.168.42.2',
      :mac_address => ''
    )

    @reservation = ::Proxy::DHCP::Reservation.new(@hostname, @ip, @mac, ::Proxy::DHCP::Subnet.new(@subnet_ip, '255.255.255.0'),
                                                  :hostname => @hostname, :nextServer => @nextserver, :filename => @filename,
                                                  :deleteable => true)

    @reservation_without_opts = ::Proxy::DHCP::Reservation.new(@hostname, @ip, @mac, ::Proxy::DHCP::Subnet.new(@subnet_ip, '255.255.255.0'),
                                                             :hostname => @hostname, :deleteable => true)

    @reservation_dnsonly = ::Proxy::DHCP::Reservation.new('dnsonly.test.com', '192.168.42.2', '00:00:00:00:00:00',
                                                        ::Proxy::DHCP::Subnet.new(@subnet_ip, '255.255.255.0'),
                                                        :hostname => 'dnsonly.test.com', :deleteable => true)
  end

  def test_all_hosts_with_find_by_record_type
    ::Infoblox::Host.expects(:find).with(@connection, 'ipv4addr~' => '192\.168\.42\..+', 'view' => @view,
                                         '_max_results' => 2147483646).returns([@host])
    assert_equal @reservation, @crud.all_hosts('192.168.42.0/24').first
  end

  def test_all_hosts_with_find_by_used
    @crud_used = ::Proxy::DHCP::Infoblox::HostIpv4AddressCRUD.new(@connection, @view, 'used')
    ::Infoblox::Ipv4address.expects(:find).with(@connection, 'network' => '192.168.42.0/24', 'status' => 'USED',
                                         '_max_results' => 2147483646).returns([@ipv4address])
    assert_equal @reservation_without_opts, @crud_used.all_hosts('192.168.42.0/24').first
  end

  def test_all_hosts_with_find_by_used_dns_record_creates_reservation
    @crud_dnsonly = ::Proxy::DHCP::Infoblox::HostIpv4AddressCRUD.new(@connection, @view, 'used')
    ::Infoblox::Ipv4address.expects(:find).with(@connection, 'network' => '192.168.42.0/24', 'status' => 'USED',
                                                '_max_results' => 2147483646).returns([@ipv4address_dnsonly])
    assert_equal @reservation_dnsonly, @crud_dnsonly.all_hosts('192.168.42.0/24').first
  end

  def test_build_host
    built = @crud.build_host(:hostname => @hostname, :mac => @mac, :ip => @ip, :nextServer => @nextserver,
                             :filename => @filename, :deleteable => true)

    assert_equal @host.name, built.name
    assert_equal @host.ipv4addrs.size, built.ipv4addrs.size

    expected_addr = @host.ipv4addrs.first
    actual_addr = built.ipv4addrs.first

    assert_equal expected_addr.ipv4addr, actual_addr.ipv4addr
    assert_equal expected_addr.mac, actual_addr.mac
    assert expected_addr.nextserver, actual_addr.nextserver
    assert actual_addr.use_nextserver
    assert_equal expected_addr.bootfile, actual_addr.bootfile
    assert actual_addr.use_bootfile
    assert actual_addr.configure_for_dhcp
    assert_equal @view, built.view
  end

  def test_add_record_with_collision
    @crud.expects(:build_host).with(:ip => @ip, :mac => @mac, :hostname => @hostname).returns(@host)
    @host.expects(:post).raises(Infoblox::Error.new("IB.Data.Conflict"))
    @crud.expects(:find_hosts).with('ipv4addr' => @ip).returns(
      [::Infoblox::Host.new(:name => @hostname, :ipv4addrs => [{ :ipv4addr => @ip, :mac => '11:22:33:44:55:66"', :configure_for_dhcp => true }])])

    assert_raises(Proxy::DHCP::Collision) { @crud.add_record(:ip => @ip, :mac => @mac, :hostname => @hostname) }
  end

  def search_condition(a_hash)
    { 'view' => @view }.merge(a_hash)
  end
end

class FixedaddressCrudTest < Test::Unit::TestCase
  include CommoncrudTests

  def setup
    @connection = Object.new
    @network_view = "something"
    @crud = ::Proxy::DHCP::Infoblox::FixedAddressCRUD.new(@connection, @network_view, 'record_type')

    @entity = ::Infoblox::Fixedaddress

    @hostname = 'test.test.com'
    @mac = '00:01:02:03:05:06'
    @nextserver = '192.168.42.1'
    @filename = '/tftpboot.img'
    @ip = '192.168.42.1'
    @subnet_ip = '192.168.42.0'

    @host = ::Infoblox::Fixedaddress.new(
      :name => @hostname,
      :ipv4addr => @ip, :mac => @mac, :network_view => @network_view)
    @host1 = ::Infoblox::Fixedaddress.new(
      :name => 'another.test.com',
      :ipv4addr => @ip, :mac => '00:01:02:03:05:07', :network_view => @network_view)

    @ipv4address = ::Infoblox::Ipv4address.new(
      :names => [@hostname],
      :ip_address => @ip,
      :mac_address => @mac
    )

    @ipv4address_dnsonly = ::Infoblox::Ipv4address.new(
      :names => ['dnsonly.test.com'],
      :ip_address => '192.168.42.2',
      :mac_address => ''
    )

    @reservation = ::Proxy::DHCP::Reservation.new(@hostname, @ip, @mac, ::Proxy::DHCP::Subnet.new(@subnet_ip, '255.255.255.0'),
                                                  :deleteable => true, :hostname => @hostname)

    @reservation_without_opts = ::Proxy::DHCP::Reservation.new(@hostname, @ip, @mac, ::Proxy::DHCP::Subnet.new(@subnet_ip, '255.255.255.0'),
                                                             :hostname => @hostname, :deleteable => true)

    @reservation_dnsonly = ::Proxy::DHCP::Reservation.new('dnsonly.test.com', '192.168.42.2', '00:00:00:00:00:00',
                                                        ::Proxy::DHCP::Subnet.new(@subnet_ip, '255.255.255.0'),
                                                        :hostname => 'dnsonly.test.com', :deleteable => true)
  end

  def test_all_hosts_with_find_by_record_type
    ::Infoblox::Fixedaddress.expects(:find).with(@connection, 'network' => '192.168.42.0/24', 'network_view' => @network_view,
                                                 '_max_results' => 2147483646).returns([@host])
    assert_equal @reservation, @crud.all_hosts('192.168.42.0/24').first
  end

  def test_all_hosts_with_find_by_used
    @crud_used = ::Proxy::DHCP::Infoblox::FixedAddressCRUD.new(@connection, @network_view, 'used')
    ::Infoblox::Ipv4address.expects(:find).with(@connection, 'network' => '192.168.42.0/24', 'status' => 'USED',
                                                '_max_results' => 2147483646).returns([@ipv4address])
    assert_equal @reservation_without_opts, @crud_used.all_hosts('192.168.42.0/24').first
  end

  def test_all_hosts_with_find_by_used_dns_record_creates_reservation
    @crud_dnsonly = ::Proxy::DHCP::Infoblox::FixedAddressCRUD.new(@connection, @network_view, 'used')
    ::Infoblox::Ipv4address.expects(:find).with(@connection, 'network' => '192.168.42.0/24', 'status' => 'USED',
                                                '_max_results' => 2147483646).returns([@ipv4address_dnsonly])
    assert_equal @reservation_dnsonly, @crud_dnsonly.all_hosts('192.168.42.0/24').first
  end

  def test_build_host
    built = @crud.build_host(:hostname => @hostname, :mac => @mac, :ip => @ip, :nextServer => @nextserver,
                             :filename => @filename, :deleteable => true)

    assert_equal @host.name, built.name
    assert_equal @host.ipv4addr, built.ipv4addr
    assert_equal @host.mac, built.mac
    assert_equal @nextserver, built.nextserver
    assert built.use_nextserver
    assert_equal @filename, built.bootfile
    assert built.use_bootfile
    assert_equal @network_view, built.network_view
  end

  def test_build_host_with_options
    begin
      Proxy::DHCP::Infoblox::Plugin.settings.options = [{"name" => "xyz"}]

      host = @crud.build_host(:ip => @ip, :mac => @mac, :hostname => @hostname)
      assert_equal [{"name" => "xyz"}], host.instance_variable_get("@options")
    ensure
      Proxy::DHCP::Infoblox::Plugin.settings.options = []
    end
  end

  def test_add_record_with_collision
    @crud.expects(:build_host).with(:ip => @ip, :mac => @mac, :hostname => @hostname).returns(@host)
    @host.expects(:post).raises(Infoblox::Error.new("IB.Data.Conflict"))
    @crud.expects(:find_hosts).with('ipv4addr' => @ip).returns(
      [::Infoblox::Fixedaddress.new(:name => @hostname, :ipv4addr => @ip, :mac => '11:22:33:44:55:66',
                                    :network_view => @network_view)])

    assert_raises(Proxy::DHCP::Collision) { @crud.add_record(:ip => @ip, :mac => @mac, :hostname => @hostname) }
  end

  def search_condition(a_hash)
    { 'network_view' => @network_view }.merge(a_hash)
  end
end
