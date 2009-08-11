# 
# Copyright (C) 2008 Red Hat, Inc.
# Written by Scott Seago <sseago@redhat.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; version 2 of the License.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
# MA  02110-1301, USA.  A copy of the GNU General Public License is
# also available at http://www.gnu.org/copyleft/gpl.html.

require File.dirname(__FILE__) + '/../test_helper'

class NicTest < ActiveSupport::TestCase
  fixtures :ip_addresses
  fixtures :nics
  fixtures :hosts
  fixtures :networks
  fixtures :vms

  def setup
    @nic = Nic.new(
         :mac => '00:11:22:33:44:55',
         :usage_type => 1,
         :bandwidth => 100 )
    @nic.host = hosts(:prod_corp_com)
    @nic.network = networks(:static_physical_network_one)

    @ip_address = IpV4Address.new(
         :address => '1.2.3.4',
         :netmask => '2.3.4.5',
         :gateway => '3.4.5.6',
         :broadcast => '4.5.6.7' )

    @nic.ip_addresses << @ip_address
  end

  def test_valid_fails_without_mac
    @nic.mac = ''

    flunk 'Nic must have a mac' if @nic.valid?
  end

  def test_valid_fails_with_invalid_mac
    @nic.mac = 'foobar'

    flunk 'Nic must have a valid mac' if @nic.valid?
  end

  def test_valid_fails_without_host
    @nic.host = nil

    flunk 'Nic must have a host' if @nic.valid?
  end

  def test_valid_fails_without_unique_physical_network
    @nic.host = hosts(:ldapserver_managed_node)

    assert_equal false, @nic.valid?, 'This nic is not valid'
    flunk 'This physical network is already used on this host.' if @nic.valid?
  end

  def test_valid_fails_with_invalid_bandwidth
    @nic.bandwidth = -1

    flunk 'Nic bandwidth must be >= 0' if @nic.valid?
  end

  def test_static_network_nic_must_have_ip
    @nic.network = networks(:static_physical_network_one)
    @nic.ip_addresses.delete_if { true }

    flunk 'Nics assigned to static networks must have at least one ip' if @nic.valid?
  end

  def test_vm_nic_must_have_network
     @nic.host = nil
     @nic.vm = vms(:production_httpd_vm)
     flunk 'vm nic that is assigned to network is valid' unless @nic.valid?

     @nic.network = nil
     flunk 'vm nic without a network is not valid' if @nic.valid?
  end

  def test_host_nic_cant_be_assigned_to_vlan
     @nic.network = networks(:dhcp_vlan_one)
     flunk 'host nic cant be assgined to vlan' if @nic.valid?
  end

  def test_nic_networking
     flunk 'nic.networking? should return true if assigned to network' unless @nic.networking?
     @nic.network = nil
     flunk 'nic.networking? should return false if not assigned to network' if @nic.networking?
  end

  def test_nic_boot_protocol
      nic = Nic.new
      nic.ip_addresses << @ip_address
      nic.network = networks(:static_physical_network_one)
      flunk 'incorrect nic boot protocol' unless nic.boot_protocol == 'static'
  end

  def test_nic_ip_addresses
      nic = Nic.new
      nic.ip_addresses << @ip_address
      nic.network = networks(:static_physical_network_one)
      flunk 'incorrect nic ip address' unless nic.ip_address == @ip_address.address
  end

  def test_nic_netmask
      nic = Nic.new
      network = Network.new
      network.ip_addresses << @ip_address
      nic.network = network

      flunk 'incorrect nic netmask' unless nic.netmask == @ip_address.netmask
  end

  def test_nic_broadcast
      nic = Nic.new
      network = Network.new
      network.ip_addresses << @ip_address
      nic.network = network

      flunk 'incorrect nic broadcast' unless nic.broadcast == @ip_address.broadcast
  end

  def test_nic_gateway
      nic = Nic.new
      network = Network.new
      network.ip_addresses << @ip_address
      nic.network = network

      flunk 'incorrect nic gateway' unless nic.gateway == @ip_address.gateway
  end

  def test_nic_parent
      flunk 'incorrect host nic parent' unless @nic.parent == hosts(:prod_corp_com)

      @nic.host = nil
      flunk 'incorrect nic parent' unless @nic.parent == nil

      @nic.vm = vms(:production_httpd_vm)
      flunk 'incorrect vm nic parent' unless @nic.parent == vms(:production_httpd_vm)
  end

  def test_nic_gen_mac
      mac = Nic::gen_mac
      flunk 'invalid generated mac' unless mac =~ /^([0-9a-fA-F]{2}([:-]|$)){6}$/
  end

  def test_nic_vm_xor_nic_host
      flunk 'host nic without vm is valid' unless @nic.valid?

      @nic.vm = vms(:production_httpd_vm)
      flunk 'nic cannot specify both host and vm' if @nic.valid?

      @nic.host = nil
      flunk 'vm nic without host is valid' unless @nic.valid?

      @nic.vm = nil
      flunk 'nic must specify either host or vm' if @nic.valid?
  end
end
