#
# Copyright (C) 2009 Red Hat, Inc.
# Written by Steve Linabery <slinabery@redhat.com>
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

class AddVmStateAudit < ActiveRecord::Migration
  def self.up
    add_column :vms, :total_uptime, :integer, :default => 0
    add_column :vms, :total_uptime_timestamp, :timestamp

    create_table :vm_state_change_events do |t|
      t.timestamp :created_at
      t.integer :vm_id
      t.string :from_state
      t.string :to_state
      t.integer :lock_version, :default => 0
    end

    Vm.transaction do
      Vm.find(:all).each do |vm|
        event = VmStateChangeEvent.new(:vm_id => vm.id,
                                       :to_state => vm.state
                                      )
        event.save!
        vm.total_uptime = 0
        vm.save!
      end
    end
  end

  def self.down
    remove_column :vms, :total_uptime
    remove_column :vms, :total_uptime_timestamp

    drop_table :vm_state_change_events
  end
end
