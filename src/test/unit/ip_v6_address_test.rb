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

class IpV6AddressTest < ActiveSupport::TestCase
  def setup
    @address = IpV6Address.new(:address => 'fe80:0:0:0:200:f8ff:fe21:67cf',
                              :gateway => ':::::::717',
                              :prefix  => '0000:0000:0000:0000:1234:1234:1234:1234',
                              :nic_id => 1)
  end

  # Ensures that the address must be provided.
  #
  def test_valid_fails_without_address
    @address.address = nil
    flunk "An address must be provided." if @address.valid?
  end

  # Ensures that the address must be in the correct format.
  #
  def test_valid_fails_with_bad_address
    @address.address = "farkle"

    flunk "The address must be in the correct format." if @address.valid?
  end

  # Ensures that the gateway must be provided.
  #
  def test_valid_fails_without_gateway
    @address.network_id = 1
    @address.gateway = nil

    flunk "The gateway address must be provided." if @address.valid?
  end

  # Ensures that the gateway address is in the correct format.
  #
  def test_valid_fails_with_bad_gateway
    @address.network_id = 1
    @address.gateway = '0-:::::::717'

    flunk "The gateway address must be in the correct format." if @address.valid?
  end

  # Ensures that the prefix must be provided.
  #
  def test_valid_fails_without_prefix
    @address.network_id = 1
    @address.prefix = nil

    flunk "The prefix must be provided." if @address.valid?
  end

  # Ensures that the prefix is in the correct format.
  #
  def test_valid_fails_with_invalid_prefix
    @address.network_id = 1
    @address.prefix = 'whoops'

    flunk "The prefix must be in the correct format." if @address.valid?
  end

  # Ensures that a well-formed address is considered valid.
  #
  def test_valid
    flunk "There is an problem with address validation." unless @address.valid?
  end
end
