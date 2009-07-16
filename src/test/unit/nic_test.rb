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

  def setup
    @nic = Nic.new(
         :mac => '00:11:22:33:44:55',
         :usage_type => 1,
         :bandwidth => 100 )
    @nic.host = hosts(:prod_corp_com)
    @nic.physical_network = networks(:static_physical_network_one)

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
    @nic.physical_network = networks(:static_physical_network_one)
    @nic.ip_addresses.delete_if { true }

    flunk 'Nics assigned to static networks must have at least one ip' if @nic.valid?
  end

end
