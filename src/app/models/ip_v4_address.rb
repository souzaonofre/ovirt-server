# ip_v4_address.rb
#
# Copyright (C) 2008 Red Hat, Inc.
# Written by Darryl L. Pierce <dpierce@redhat.com>,
#            Mohammed Morsi   <mmorsi@redhat.com>
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

# +IpV4Address+ represents a single IPv4 address.
#
class IpV4Address < IpAddress
  ADDRESS_TEST = %r{^(\d{1,3}\.){3}\d{1,3}$}

  validates_presence_of :address,
    :message => 'An address must be supplied.'
  validates_format_of :address,
    :with => ADDRESS_TEST

  validates_presence_of :netmask,
    :message => 'A netmask must be supplied.',
    :if => Proc.new { |ip| ip.network_id != nil }
  validates_format_of :netmask,
    :with => ADDRESS_TEST,
    :if => Proc.new { |ip| ip.network_id != nil }

  validates_presence_of :gateway,
    :message => 'A gateway address must be supplied.',
    :if => Proc.new { |ip| ip.network_id != nil }
  validates_format_of :gateway,
    :with => ADDRESS_TEST,
    :if => Proc.new { |ip| ip.network_id != nil }

  validates_presence_of :broadcast,
    :message => 'A broadcast address must be supplied.',
    :if => Proc.new { |ip| ip.network_id != nil }
  validates_format_of :broadcast,
    :with => ADDRESS_TEST,
    :if => Proc.new { |ip| ip.network_id != nil }

end
