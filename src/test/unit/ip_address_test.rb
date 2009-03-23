require File.dirname(__FILE__) + '/../test_helper'

class IpAddressTest < ActiveSupport::TestCase
  fixtures :boot_types, :bondings, :networks, :nics, :ip_addresses

  def test_can_retrieve_nic
    assert_equal ip_addresses(:ip_v4_mailserver_nic_one).nic.bandwidth.to_s, '100'
  end

  def test_can_get_ipaddress_object
    assert_equal ip_addresses(:ip_v4_mailserver_nic_one).address, '172.31.0.15'
  end

  def test_valid_fails_without_foreign_entity
     @ip_address = IpAddress.new
     flunk "Ip Address must be associated with network, nic, or bonding" if @ip_address.valid?
  end
end
