#
# Copyright (C) 2008 Red Hat, Inc.
# Written by Darryl L. Pierce <dpierce@redhat.com>
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

class BondingTest < ActiveSupport::TestCase
  fixtures :bondings
  fixtures :bonding_types
  fixtures :bondings_nics
  fixtures :boot_types
  fixtures :hosts
  fixtures :nics
  fixtures :networks

  def setup
    @bonding = Bonding.new(
      :name            => 'Bonding1',
      :interface_name  => 'bond0',
      :bonding_type_id => bonding_types(:failover_bonding_type),
      :host_id         => hosts(:mailservers_managed_node))
    @bonding.vlan = networks(:dhcp_vlan_one)
    @bonding.bonding_type = bonding_types(:load_balancing_bonding_type)
  end

  # Ensures that the name is required.
  #
  def test_valid_fails_without_name
    @bonding.name = ''

    flunk 'Bondings having to have a name.' if @bonding.valid?
  end

  # Ensures that the interface name is required.
  #
  def test_valid_fails_without_interface_name
    @bonding.interface_name = ''

    flunk 'Bondings have to have an interface name.' if @bonding.valid?
  end

  # Ensures that the bonding type is required.
  #
  def test_valid_fails_without_type
    @bonding.bonding_type_id = nil

    flunk 'Bondings have to have a valid type.' if @bonding.valid?
  end

  # Ensures that a host is required
  #
  def test_valid_fails_without_host
    @bonding.host_id = nil

    flunk 'Bondings have to have a host.' if @bonding.valid?
  end

  def test_valid_fails_without_bonding_type
    @bonding.bonding_type = nil
    flunk 'Bonding must specify bonding type' if @bonding.valid?
  end

  def test_valid_fails_without_vlan
    @bonding.vlan = nil
    flunk 'Bonding must specify vlan' if @bonding.valid?
  end

  # Ensures that an arp ping address must have the correct format
  #
  def test_valid_fails_with_bad_arp_ping_address
    @bonding.arp_ping_address = 'foobar'

    flunk "An arp ping address must be in the format ##.##.##.##." if @bonding.valid?
  end

  # Ensures that an arp interval is a numerical value >= 0
  #
  def test_valid_fails_with_bad_arp_interval
    @bonding.arp_interval = -1

    flunk "An arp interval must be >= 0" if @bonding.valid?
  end

  def test_static_network_bonding_must_have_ip
    @bonding.vlan = networks(:static_vlan_one)
    @bonding.ip_addresses.delete_if { true }

    flunk 'Bonding assigned to static networks must have at least one ip' if @bonding.valid?
  end


  # Ensure that retrieving a bonding returns its associated objects.
  #
  def test_find_all_for_host
    result = Bonding.find_all_by_host_id(hosts(:mailservers_managed_node))

    assert_equal 1, result.size, 'Did not find the right number of bondings.'
    assert result[0].nics.empty? == false, 'Did not load any nics.'
    assert_equal 2, result[0].nics.size, 'Did not load the right set of nics.'
  end

end
