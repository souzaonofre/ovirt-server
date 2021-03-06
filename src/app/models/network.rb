# Copyright (C) 2008 Red Hat, Inc.
# Written by Mohammed Morsi <mmorsi@redhat.com>
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

class Network < ActiveRecord::Base
  belongs_to :boot_type
  has_many :ip_addresses, :dependent => :destroy

  has_and_belongs_to_many :usages, :join_table => 'networks_usages'

  has_many :nics

  validates_presence_of :type,
    :message => 'A type must be specified.'
  validates_presence_of :name,
    :message => 'A name must be specified.'
  validates_presence_of :boot_type_id,
    :message => 'A boot type must be specified.'

  def self.factory(params = {})
    case params[:type]
    when 'PhysicalNetwork'
      return PhysicalNetwork.new(params)
    when 'Vlan'
      return Vlan.new(params)
    else
      raise ArgumentError("Invalid type #{params[:type]}")
    end
  end


end
