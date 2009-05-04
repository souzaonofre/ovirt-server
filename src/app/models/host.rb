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

require 'util/ovirt'

class Host < ActiveRecord::Base
  belongs_to :hardware_pool
  belongs_to :bonding_type

  has_many :membership_audit_events, :as => :member_target, :dependent => :destroy, :order => "created_at ASC" do
    def from_pool(pool,startTime,endTime)
      find(:all, :conditions=> ['container_target_id = ? and created_at between ? and ?',pool,startTime,endTime])
    end
    def most_recent_prior_event_from_pool(pool,startTime)
      find(:last, :conditions=> ['container_target_id = ? and created_at < ?',pool,startTime])
    end
  end

  has_many :cpus,     :dependent => :destroy
  has_many :nics,     :dependent => :destroy
  has_many :bondings, :dependent => :destroy
  has_many :vms,      :dependent => :nullify do
    def consuming_resources
      find(:all, :conditions=>{:state=>Vm::RUNNING_STATES})
    end
  end

  has_many :tasks, :as => :task_target, :dependent => :destroy, :order => "id ASC" do
    def queued
      find(:all, :conditions=>{:state=>Task::STATE_QUEUED})
    end
    def pending_clear_tasks
      find(:all, :conditions=>{:state=>Task::WORKING_STATES,
                               :action=>HostTask::ACTION_CLEAR_VMS})
    end
  end

  has_many :smart_pool_tags, :as => :tagged, :dependent => :destroy
  has_many :smart_pools, :through => :smart_pool_tags

  # reverse cronological collection of vm history
  # each collection item contains vm that was running on host
  # time started, and time ended (see VmHostHistory)
  has_many :vm_host_histories,
           :order => 'time_started DESC',
           :dependent => :destroy

  alias history vm_host_histories

  acts_as_xapian :texts => [ :hostname, :uuid, :hypervisor_type, :arch ],
                 :values => [ [ :created_at, 0, "created_at", :date ],
                              [ :updated_at, 1, "updated_at", :date ] ],
                 :terms => [ [ :hostname, 'H', "hostname" ],
                             [ :search_users, 'U', "search_users" ] ],
                 :eager_load => :smart_pools

  validates_presence_of :hardware_pool_id,
     :message => 'A hardware pool id must be specified.'

  validates_presence_of :hostname,
     :message => 'A hostname must be specified.'

  validates_presence_of :arch,
     :message => 'An arch must be specified.'

  KVM_HYPERVISOR_TYPE = "KVM"
  QEMU_HYPERVISOR_TYPE = "QEMU"
  HYPERVISOR_TYPES = [KVM_HYPERVISOR_TYPE, QEMU_HYPERVISOR_TYPE]
  STATE_UNAVAILABLE = "unavailable"
  STATE_AVAILABLE   = "available"
  STATES = [STATE_UNAVAILABLE, STATE_AVAILABLE]

  validates_inclusion_of :hypervisor_type,
     :in => HYPERVISOR_TYPES,
     :unless => Proc.new { |host| host.hypervisor_type.nil? or host.hypervisor_type == "" }

  validates_inclusion_of :state,
     :in => STATES + Task::COMPLETED_STATES + Task::WORKING_STATES

  def memory_in_mb
    kb_to_mb(memory)
  end

  def memory_in_mb=(mem)
    self[:memory]=(mb_to_kb(mem))
  end

  def status_str
    "#{state} (#{disabled? ? 'disabled':'enabled'})"
  end

  def disabled?
    not(is_disabled.nil? or is_disabled==0)
  end

  def is_clear_task_valid?
    state==STATE_AVAILABLE and
      not(disabled? and vms.consuming_resources.empty?) and
      tasks.pending_clear_tasks.empty?
  end

  def num_cpus
    return cpus.size
  end

  def cpu_speed
    cpus[0].speed unless cpus.empty?
  end

  def display_name
    hostname
  end
  def display_class
    "Host"
  end

  def search_users
    hardware_pool.search_users
  end

  def permission_obj
    hardware_pool
  end

  def movable?
     return vms.size == 0
  end

end
