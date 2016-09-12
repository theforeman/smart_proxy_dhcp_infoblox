require 'test_helper'
require 'smart_proxy_dhcp_infoblox/network_address_range_regex_generator'

class RangeRegExGeneratorTest < Test::Unit::TestCase
  def setup
    @generator = ::Proxy::DHCP::Infoblox::RangeRegularExpressionGenerator.new
  end

  def test_full_range_single_digit
    assert_equal "(0?0?[0123456789])", @generator.range_regex(0, 9)
  end

  def test_single_digits_range
    assert_equal "(0?0?[34567])", @generator.range_regex(3, 7)
  end

  def test_neighbour_numbers_single_digits_range
    assert_equal "(0?0?[12])", @generator.range_regex(1, 2)
  end

  def test_full_range_double_digits
    assert_equal "(0?[123456789][0123456789])", @generator.range_regex(10, 99)
  end

  def test_range_double_digits
    assert_equal "(0?3[3456789]|0?[456][0123456789]|0?7[01234567])", @generator.range_regex(33, 77)
  end

  def test_neighbour_numbers_double_digits_range
    assert_equal "(0?5[56])", @generator.range_regex(55, 56)
  end

  def test_single_and_double_digit_full_range
    assert_equal "(0?0?[0123456789]|0?[123456789][0123456789])", @generator.range_regex(0, 99)
  end

  def test_full_range_triple_digits
    assert_equal "([123456789][0123456789][0123456789])", @generator.range_regex(100, 999)
  end

  def test_range_triple_digits
    assert_equal "(12[56789]|1[3456789][0123456789]|[23456][0123456789][0123456789]|7[012][0123456789]|73[01234])", @generator.range_regex(125, 734)
  end

  def test_neighbour_numbers_triple_digits_range
    assert_equal "(34[56])", @generator.range_regex(345, 346)
  end

  def test_single_double_and_triple_digit_full_range
    assert_equal "(0?0?[0123456789]|0?[123456789][0123456789]|[123456789][0123456789][0123456789])", @generator.range_regex(0, 999)
  end
end

class NetworkAddressesRegularExpressionGeneratorTest < Test::Unit::TestCase
  def setup
    @generator = ::Proxy::DHCP::Infoblox::NetworkAddressesRegularExpressionGenerator.new
  end

  def test_ranges_with_cidrs_of_multiples_of_8bit
    assert_equal [[1, 1], [0, 255], [0, 255], [0, 255]], @generator.network_cidr_range_octets('1.0.0.0/8')
    assert_equal [[10, 10], [10, 10], [0, 255], [0, 255]], @generator.network_cidr_range_octets('10.10.0.0/16')
    assert_equal [[33, 33], [34, 34], [35, 35], [0, 255]], @generator.network_cidr_range_octets('33.34.35.0/24')
  end

  def test_ranges_with_cidrs_non_multiples_of_8bits
    assert_equal [[240, 255], [0, 255], [0, 255], [0, 255]], @generator.network_cidr_range_octets('240.0.0.0/4')
    assert_equal [[10, 10], [128, 255], [0, 255], [0, 255]], @generator.network_cidr_range_octets('10.128.0.0/9')
    assert_equal [[192, 192], [168, 168], [42, 42], [64, 127]], @generator.network_cidr_range_octets('192.168.42.64/26')
  end

  def test_cidr16_range_to_regex
    assert_equal '10\.10\..+\..+', @generator.range_to_regex([[10, 10], [10, 10], [0, 255], [0, 255]])
  end

  def test_cidr9_range_to_regex
    assert_equal '10\.(129|1[3456789][0123456789]|2[01234][0123456789]|25[01234])\..+\..+', @generator.range_to_regex([[10, 10], [128, 255], [0, 255], [0, 255]])
  end

  def test_cidr26_range_to_regex
    assert_equal '192\.168\.42\.(0?6[56789]|0?[789][0123456789]|1[01][0123456789]|12[0123456])', @generator.range_to_regex([[192, 192], [168, 168], [42, 42], [64, 127]])
  end

  def test_generate_regex
    assert_equal '192\.168\.42\.(0?6[56789]|0?7[012345678])', @generator.generate_regex('192.168.42.64/28')
  end
end
