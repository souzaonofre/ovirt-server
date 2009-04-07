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

  # FIXME bondings_nics table should just be replaced with
  # bonding_id column in nics table, and relationship changed
  # here to belongs_to
  has_and_belongs_to_many :bondings, :join_table => 'bondings_nics'

  validates_presence_of :mac,
    :message => 'A mac address must be specified.'

  validates_format_of :mac,
    :with => %r{^([0-9a-fA-F]{2}([:-]|$)){6}$}

  validates_presence_of :host_id,
    :message => 'A host must be specified.'

  validates_numericality_of :bandwidth,
     :greater_than_or_equal_to => 0

  validates_uniqueness_of :physical_network_id,
     :scope => :host_id,
     :unless => Proc.new { |nic| nic.physical_network_id.nil? }

  # Returns whether the nic has networking defined.
  def networking?
    (physical_network != nil)
  end

  # Returns the boot protocol for the nic if networking is defined.
  def boot_protocol
    return physical_network.boot_type.proto if networking?
  end

  # Returns whether the nic is enslaved by a bonded interface.
  def bonded?
    !bondings.empty?
  end

  # Returns the ip address for the nic if networking is defined.
  def ip_address
    return ip_addresses.first.address if networking? && !ip_addresses.empty?
    return nil
  end

  # Returns the netmask for the nic if networking is defined.
  def netmask
    return physical_network.ip_addresses.first.netmask if networking? && !physical_network.ip_addresses.empty?
    return nil
  end

  # Returns the broadcast address for the nic if networking is defined.
  def broadcast
    return physical_network.ip_addresses.first.broadcast if networking? && !physical_network.ip_addresses.empty?
    return nil
  end

  # Returns the gateway address fo rthe nic if networking is defined.
  def gateway
    return physical_network.ip_addresses.first.gateway if networking? && !physical_network.ip_addresses.empty?
    return nil
  end

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
