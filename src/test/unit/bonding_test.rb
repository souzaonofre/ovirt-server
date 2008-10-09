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
  fixtures :hosts
  fixtures :nics

  def setup
    @bonding = Bonding.new(
      :name            => 'Bonding1',
      :interface_name  => 'bond0',
      :bonding_type_id => bonding_types(:failover_bonding_type),
      :host_id         => hosts(:mailservers_managed_node))
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

  # Ensure that retrieving a bonding returns its associated objects.
  #
  def test_find_all_for_host
    result = Bonding.find_all_by_host_id(hosts(:mailservers_managed_node))

    assert_equal 1, result.size, 'Did not find the right number of bondings.'
    assert result[0].nics.empty? == false, 'Did not load any nics.'
    assert_equal 2, result[0].nics.size, 'Did not load the right set of nics.'
  end

end
