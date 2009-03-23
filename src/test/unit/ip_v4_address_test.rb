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

class IpV4AddressTest < ActiveSupport::TestCase
  def setup
    @address = IpV4Address.new(:address   => '192.168.50.2',
                              :netmask   => '255.255.255.0',
                              :gateway   => '192.168.50.1',
                              :broadcast => '192.168.50.255',
                              :nic_id => 1)
  end

  # Ensures that an address must be supplied.
  #
  def test_valid_fails_without_address
    @address.address = nil

    flunk "An address must be present." if @address.valid?
  end

  # Ensures that an address has to be in the correct format.
  #
  def test_valid_fails_with_bad_address
    @address.address = '192.168'

    flunk "An address must be in the format ##.##.##.##." if @address.valid?
  end

  # Ensures that a netmask must be supplied.
  #
  def test_valid_fails_without_netmask
    @address.network_id = 1
    @address.netmask = nil

    flunk "An address must have a netmask." if @address.valid?
  end

  # Ensures that a netmask must have the correct format.
  #
  def test_valid_fails_with_bad_netmask
    @address.network_id = 1
    @address.netmask = 'farkle'

    flunk "A netmask must be in the format ##.##.##.##." if @address.valid?
  end

  # Ensures that a gateway must be supplied.
  #
  def test_valid_fails_without_gateway
    @address.network_id = 1
    @address.gateway = nil

    flunk "A gateway address must be supplied." if @address.valid?
  end

  # Ensures that a gateway must be in the correct format.
  #
  def test_valid_fails_with_bad_gateway
    @address.network_id = 1
    @address.gateway = '-3.a2.0.8'


    flunk "The gateway address must be in the format ##.##.##.##." if @address.valid?
  end

  # Ensures that a broadcast must be supplied.
  #
  def test_valid_fails_without_broadcast
    @address.network_id = 1
    @address.broadcast = nil

    flunk "A broadcast addres must be supplied." if @address.valid?
  end

  # Ensures that a broadcast must be in the correct format.
  #
  def test_valid_fails_with_bad_broadcast
    @address.network_id = 1
    @address.broadcast = '-3.2.0.8'

    flunk "The broadcast address must be in the format ##.##.##.##." if @address.valid?
  end

  # Ensures that a well-formed address is valid.
  #
  def test_valid
    flunk "There is an error with validation." unless @address.valid?
  end
end
