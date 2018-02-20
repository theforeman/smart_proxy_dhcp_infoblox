require "rack/test"
require 'test_helper'
require 'json'
require 'dhcp_common/dhcp_common'
require 'dhcp/dhcp'
require 'dhcp/dependency_injection'
require 'dhcp/dhcp_api'

ENV['RACK_ENV'] = 'test'

class IntegrationTest < ::Test::Unit::TestCase
  include Rack::Test::Methods

  def app
    app = Proxy::DhcpApi.new
    app.helpers.server = @server
    app
  end

  def setup
    @free_ips = ::Proxy::DHCP::FreeIps.new
    @server = ::Proxy::DHCP::Infoblox::Provider.new(nil, Object.new, Object.new, @free_ips, [],
                                                    "default")

    @expected_reservation = {"name" => "testing-01", "ip" => "10.0.0.200", "mac" => "11:22:33:a9:61:09",
                             "subnet" => "10.0.0.0/255.255.255.0", "hostname" => "testing-01"}
  end


  def test_get_subnets
    @server.expects(:subnets).returns([])
    get "/"
    assert last_response.ok?, "Last response was not ok: #{last_response.status} #{last_response.body}"
  end

  def test_get_network
    @server.expects(:all_hosts).with("10.0.0.0").returns([@expected_reservation])
    @server.expects(:all_leases).with("10.0.0.0").returns([])

    get "/10.0.0.0"

    assert last_response.ok?, "Last response was not ok: #{last_response.status} #{last_response.body}"
  end

  def test_get_unused_ip
    @server.expects(:get_subnet).with("10.0.0.0").returns(::Proxy::DHCP::Subnet.new("10.0.0.0", "255.255.255.0"))
    @server.expects(:all_hosts).with("10.0.0.0").returns([@expected_reservation])
    @server.expects(:all_leases).with("10.0.0.0").returns([])
    @free_ips.expects(:find_free_ip).with("10.0.0.100", "10.0.0.200", [@expected_reservation]).returns("10.0.0.150")

    get "/10.0.0.0/unused_ip?from=10.0.0.100&to=10.0.0.200"

    assert last_response.ok?, "Last response was not ok: #{last_response.status} #{last_response.body}"
    parsed_response = JSON.parse(last_response.body)
    assert parsed_response.key?('ip')
  end

  def test_get_records_by_ip
    @server.expects(:find_records_by_ip).with("10.0.0.0", "10.0.0.200").returns([@expected_reservation])
    get "/10.0.0.0/ip/10.0.0.200"
    assert last_response.ok?, "Last response was not ok: #{last_response.status} #{last_response.body}"
    parsed_response = JSON.parse(last_response.body)
    assert_equal 1, parsed_response.size
    assert_equal @expected_reservation, parsed_response.first
  end

  def test_get_record_by_mac
    @server.expects(:find_record_by_mac).with("10.0.0.0", "11:22:33:a9:61:09").returns(@expected_reservation)
    get "/10.0.0.0/mac/11:22:33:a9:61:09"
    assert last_response.ok?, "Last response was not ok: #{last_response.status} #{last_response.body}"
    assert_equal @expected_reservation, JSON.parse(last_response.body)
  end

  def test_create_record
    record = {
        "hostname" => "test-02",
        "ip"       => "10.0.0.250",
        "mac"      => "10:10:10:10:10:10",
        "network"  => "10.0.0.0",
    }
    @server.expects(:add_record).with(has_entries(record))
    post "/10.0.0.0", record
    assert last_response.ok?, "Last response was not ok: #{last_response.status} #{last_response.body}"
  end

  def test_delete_records_by_ip
    @server.expects(:del_records_by_ip).with("10.0.0.0", "10.0.0.200")
    delete "/10.0.0.0/ip/10.0.0.200"
    assert last_response.ok?, "Last response was not ok: #{last_response.status} #{last_response.body}"
  end

  def test_delete_record_by_mac
    @server.expects(:del_record_by_mac).with("10.0.0.0", "11:22:33:a9:61:09")
    delete "/10.0.0.0/mac/11:22:33:a9:61:09"
    assert last_response.ok?, "Last response was not ok: #{last_response.status} #{last_response.body}"
  end
end
