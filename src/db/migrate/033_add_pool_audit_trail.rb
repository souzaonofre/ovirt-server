#
# Copyright (C) 2008 Red Hat, Inc.
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

class AddPoolAuditTrail < ActiveRecord::Migration
  def self.up
    create_table :membership_audit_events do |t|
      t.timestamp :created_at
      t.string :action
      t.integer :container_target_id
      t.string :container_target_type
      t.integer :member_target_id
      t.string :member_target_type
      t.integer :lock_version, :default => 0
    end

    Host.transaction do
      Host.find(:all).each do |host|

        if (host.membership_audit_events.empty?)
          event = MembershipAuditEvent.new(:action => MembershipAuditEvent::JOIN,
                                           :container_target => host.hardware_pool,
                                           :member_target => host)
          event.save!
        end
      end
    end
  end

  def self.down
    drop_table :membership_audit_events
  end
end
