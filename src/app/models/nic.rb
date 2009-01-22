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

class Nic < ActiveRecord::Base
  belongs_to :host
  belongs_to :physical_network
  has_many :ip_addresses, :dependent => :destroy

  has_and_belongs_to_many :bondings, :join_table => 'bondings_nics'

  validates_presence_of :mac,
    :message => 'A mac address must be specified.'

  validates_format_of :mac,
    :with => %r{^([0-9a-fA-F]{2}([:-]|$)){6}$}

  validates_presence_of :host_id,
    :message => 'A host must be specified.'

  validates_presence_of :physical_network_id,
    :message => 'A network must be specified.'

  validates_numericality_of :bandwidth,
     :greater_than_or_equal_to => 0

  # validate 'bridge' or 'usage_type' attribute ?

  protected
   def validate
    if ! physical_network.nil? and
       physical_network.boot_type.proto == 'static' and
       ip_addresses.size == 0
           errors.add("physical_network_id",
                      "is static. Must create at least one static ip")
     end
   end
end
