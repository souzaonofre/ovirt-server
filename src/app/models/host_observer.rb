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

class HostObserver < ActiveRecord::Observer

  def after_create(a_host)
    join = MembershipAuditEvent.new({ :member_target => a_host,
                                      :container_target => a_host.hardware_pool,
                                      :action => MembershipAuditEvent::JOIN })
    join.save!
  end

  def before_update(a_host)
    if a_host.changed?
      change = a_host.changes['hardware_pool_id']
      if change
        leave = MembershipAuditEvent.new({ :member_target => a_host,
                                           :container_target => HardwarePool.find(change[0]),
                                           :action => MembershipAuditEvent::LEAVE })
        leave.save!

        join = MembershipAuditEvent.new({ :member_target => a_host,
                                          :container_target => HardwarePool.find(change[1]),
                                          :action => MembershipAuditEvent::JOIN })
        join.save!
      end
    end
  end
end

HostObserver.instance
