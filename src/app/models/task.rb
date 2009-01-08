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

class Task < ActiveRecord::Base
  belongs_to :hardware_pool
  belongs_to :vm_resource_pool
  belongs_to :task_target,       :polymorphic => true
  # moved associations here so that nested set :include directives work
  # StorageTask association
  belongs_to :storage_pool,   :class_name => "StoragePool",
                              :foreign_key => "task_target_id"
  # StorageVolumeTask association
  belongs_to :storage_volume, :class_name => "StorageVolume",
                              :foreign_key => "task_target_id"
  # HostTask association
  belongs_to :host,           :class_name => "Host",
                              :foreign_key => "task_target_id"
  # VmTask association
  belongs_to :vm,             :class_name => "Vm",
                              :foreign_key => "task_target_id"

  STATE_QUEUED       = "queued"
  STATE_RUNNING      = "running"
  STATE_FINISHED     = "finished"
  STATE_PAUSED       = "paused"
  STATE_FAILED       = "failed"
  STATE_CANCELED     = "canceled"

  COMPLETED_STATES = [STATE_FINISHED, STATE_FAILED, STATE_CANCELED]
  WORKING_STATES   = [STATE_QUEUED, STATE_RUNNING, STATE_PAUSED]

  TASK_TYPES_OPTIONS = [["VM Task", "VmTask"],
                        ["Host Task", "HostTask"],
                        ["Storage Task", "StorageTask"],
                        ["Storage Volume Task", "StorageVolumeTask", "break"],
                        ["Show All", ""]]
  TASK_STATES_OPTIONS = [["Queued", Task::STATE_QUEUED],
                         ["Running", Task::STATE_RUNNING],
                         ["Paused", Task::STATE_PAUSED],
                         ["Finished", Task::STATE_FINISHED],
                         ["Failed", Task::STATE_FAILED],
                         ["Canceled", Task::STATE_CANCELED, "break"],
                         ["Show All", ""]]

  def cancel
    self[:state] = STATE_CANCELED
    save!
  end

  def self.working_tasks(user = nil)
    self.tasks_for_states(Task::WORKING_STATES, user)
  end

  def self.completed_tasks(user = nil)
    self.tasks_for_states(Task::COMPLETED_STATES, user)
  end

  def self.tasks_for_states(state_array, user = nil)
    conditions = state_array.collect {|x| "state='#{x}'"}.join(" or ")
    conditions = "(#{conditions}) and user='#{user}'"
    Task.find(:all, :conditions => conditions)
  end

  def type_label
    self.class.name[0..-5]
  end
  def task_obj
    ""
  end

end
