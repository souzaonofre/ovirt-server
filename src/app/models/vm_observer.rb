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

class VmObserver < ActiveRecord::Observer

  AUDIT_RUNNING_STATES = [Vm::STATE_RUNNING,
                          Vm::STATE_POWERING_OFF,
                          Vm::STATE_STOPPING,
                          Vm::STATE_STARTING,
                          Vm::STATE_RESUMING,
                          Vm::STATE_SAVING,
                          Vm::STATE_RESTORING,
                          Vm::STATE_MIGRATING]

  AUDIT_NON_RUNNING_STATES = Vm::ALL_STATES - AUDIT_RUNNING_STATES - [Vm::STATE_UNREACHABLE]

  def after_save(a_vm)
    if a_vm.changed?
      change = a_vm.changes['state']
      if change
        event = VmStateChangeEvent.new({ :vm => a_vm,
                                         :from_state => change[0],
                                         :to_state => change[1]})
        event.save!
      end
    end
  end

  def before_save(a_vm)
    if a_vm.changed?
      change = a_vm.changes['state']
      if change
        #When going from a non-running state to a running state, update the
        #total uptime timestamp to indicate the start of the running period.

        if AUDIT_NON_RUNNING_STATES.include?(change[0]) &&
            AUDIT_RUNNING_STATES.include?(change[1])
          a_vm.total_uptime_timestamp = Time.now
        end

        #When going from a running state to anything but a running state,
        #add the time since the last timestamp to the total uptime, and then
        #update the total uptime timestamp.
        #Note that this also matches the transition to unreachable

        if AUDIT_RUNNING_STATES.include?(change[0]) &&
            !AUDIT_RUNNING_STATES.include?(change[1])
          a_vm.total_uptime = a_vm.total_uptime +
            (Time.now - a_vm.total_uptime_timestamp)
          a_vm.total_uptime_timestamp = Time.now
        end


        #Leaving the unreachable state for a running state is a special case.

        if change[0] == Vm::STATE_UNREACHABLE &&
            AUDIT_RUNNING_STATES.include?(change[1])

          #We need to know from what state the Vm most recently entered the
          #unreachable state
          prev = a_vm.vm_state_change_events.previous_state_with_type(Vm::STATE_UNREACHABLE)

          if prev
            #If it entered unreachable from a running state, then we consider
            #the time spent in unreachable as running time. Add the time
            #spent in unreachable to total uptime, and update the timestamp.
            if AUDIT_RUNNING_STATES.include?(prev.from_state)
              a_vm.total_uptime = a_vm.total_uptime +
                (Time.now - a_vm.total_uptime_timestamp)
              a_vm.total_uptime_timestamp = Time.now
            end
          end
        end

      end
    end
  end
end

VmObserver.instance
