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

# A +Bonding+ represents a bonded interface on a node. It is associated with
# one (though really should be at least two) +Nic+ instances.
#
# The +name+ is the human-readable name used in the oVirt server.
#
# The +interface_name+ defines the name by which the bonded interface is
# addressed on the node.
#
# The +arp_ping_address+ and +arp_interval+ are the ip address and interval
# settings used for those nodes that require them for monitoring a bonded
# interface. They can be ignored if not used.
#
class Bonding < ActiveRecord::Base
  validates_presence_of :name,
    :message => 'A name is required.'

  validates_presence_of :host_id,
    :message => 'A host must be specified.'

  validates_presence_of :bonding_type_id,
    :message => 'A bonding type must be specified.'

  validates_presence_of :interface_name,
    :message => 'An interface name is required.'

  validates_presence_of :boot_type_id,
    :message => 'A boot type must be specified.'

  validates_presence_of :bonding_type_id,
    :message => 'A bonding type must be specified.'

  belongs_to :host
  belongs_to :bonding_type
  belongs_to :boot_type

  has_and_belongs_to_many :nics,
    :join_table  => 'bondings_nics',
    :foreign_key => :bonding_id

end
