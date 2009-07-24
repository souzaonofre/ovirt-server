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

class Vlan < Network
   has_many :bondings

   has_many :nics

  validates_presence_of :number,
    :message => 'A number must be specified.'

  def is_destroyable?
    bondings.empty? && nics.empty?
  end

  protected
   def validate
     # ensure that any assigned nics only belong to vms, not hosts
     nics.each{ |nic|
       if nic.parent.class == Host
         errors.add("nics", "must only be assigned to vms")
         break
       end
     }
   end
end
