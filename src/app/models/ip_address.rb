# ip_address.rb
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

# +IpAddress+ is the base class for all address related classes.
#
class IpAddress < ActiveRecord::Base
   # one of these 3 will apply for each address
   belongs_to :network
   belongs_to :nic
   belongs_to :bonding

  def self.factory(params = {})
    case params[:type]
    when "IpV4Address"
      return IpV4Address.new(params)
    when "IpV6Address"
      return IpV6Address.new(params)
    else
      raise ArgumentError("Invalid type #{params[:type]}")
    end
  end
end
