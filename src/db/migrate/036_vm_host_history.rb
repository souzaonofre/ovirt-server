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

# creates a vm/host history table to maintain a record
# of which vms were running on which hosts
class VmHostHistory < ActiveRecord::Migration
  def self.up
    # this table gets populated in db-omatic
    create_table :vm_host_histories do |t|
       # vm / host association
       t.integer :vm_id
       t.foreign_key :vms, :name => 'fk_vm_host_histories_vms'
       t.integer :host_id
       t.foreign_key :hosts, :name => 'fk_vm_host_histories_hosts'

       # records operating info of vm
       #  (most likey we will want to add a
       #   slew of more info here or in a future
       #   migration)
       t.integer :vnc_port
       t.string  :state

       # start / end timestamps
       t.timestamp :time_started
       t.timestamp :time_ended
    end
  end

  def self.down
    drop_table :vm_host_histories
  end
end
