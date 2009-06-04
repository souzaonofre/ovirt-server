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

class HardwarePool < Pool

  DEFAULT_POOL_NAME = "default"

  has_many :tasks, :dependent => :nullify
  def all_storage_volumes
    StorageVolume.find(:all, :include => {:storage_pool => :hardware_pool}, :conditions => "pools.id = #{id}")
  end

  def get_type_label
    "Hardware Pool"
  end

  def get_controller
    return 'hardware' 
  end

  # note: doesn't currently join w/ permissions
  def self.get_default_pool
    hw_root = DirectoryPool.get_hardware_root
    hw_root ? hw_root.named_child(DEFAULT_POOL_NAME) : nil
  end

  def total_storage_volumes
    storage_pools.inject(0) { |sum, pool| sum += pool.storage_volumes.size}
  end
  def storage_volumes
    storage_pools.collect { |pool| pool.storage_volumes}.flatten
  end

  def full_resources(exclude_vm = nil)
    total = total_resources
    labels = RESOURCE_LABELS
    return {:total => total, :labels => labels}
  end

  # params accepted:
  # :vm_to_include - if specified, storage used by this VM is included in the tree
  # :filter_unavailable - if true, don't include Storage not currently available
  # :include_used - include all storage pools/volumes, even those in use
  def storage_tree(params = {})
    vm_to_include=params.fetch(:vm_to_include, nil)
    filter_unavailable = params.fetch(:filter_unavailable, true)
    include_used = params.fetch(:include_used, false)
    conditions = "type != 'LvmStoragePool'"
    if filter_unavailable
      conditions = "(#{conditions}) and (storage_pools.state = '#{StoragePool::STATE_AVAILABLE}')"
    end
    storage_pools.find(:all,
                    :conditions => conditions).collect do |pool|
      pool.storage_tree_element(params)
    end
  end
end
