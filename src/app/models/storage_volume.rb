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

class StorageVolume < ActiveRecord::Base
  belongs_to              :storage_pool
  has_and_belongs_to_many :vms

  belongs_to :lvm_storage_pool, :class_name => "LvmStoragePool",
                            :foreign_key => "lvm_pool_id"

  has_many :tasks, :as => :task_target, :dependent => :destroy, :order => "id ASC" do
    def queued
      find(:all, :conditions=>{:state=>Task::STATE_QUEUED})
    end
  end

  STATE_PENDING_SETUP    = "pending_setup"
  STATE_PENDING_DELETION = "pending_deletion"
  STATE_AVAILABLE        = "available"

  def self.factory(type, params = {})
    params[:state] = STATE_PENDING_SETUP unless params[:state]
    case type
    when StoragePool::ISCSI
      return IscsiStorageVolume.new(params)
    when StoragePool::NFS
      return NfsStorageVolume.new(params)
    when StoragePool::LVM
      return LvmStorageVolume.new(params)
    else
      return nil
    end
  end

  def get_type_label
    StoragePool::STORAGE_TYPES.invert[self.class.name.gsub("StorageVolume", "")]
  end

  def display_name
    "#{get_type_label}: #{storage_pool.ip_addr}:#{label_components}"
  end

  def size_in_gb
    kb_to_gb(size)
  end

  def size_in_gb=(new_size)
    self[:size]=(gb_to_kb(new_size))
  end

  def self.find_for_vm(include_vm, vm_pool)
    if vm_pool
      condition =  "(vms.id is null and storage_pools.hardware_pool_id=#{vm_pool.get_hardware_pool.id})"
      condition += " or vms.id=#{include_vm.id}" if (include_vm and include_vm.id)
      self.find(:all, :include => [:vms, :storage_pool], :conditions => condition)
    else
      return []
    end
  end

  def supports_lvm_subdivision
    return false
  end

  def storage_tree_element(params = {})
    vm_to_include=params.fetch(:vm_to_include, nil)
    filter_unavailable = params.fetch(:filter_unavailable, true)
    include_used = params.fetch(:include_used, false)
    vm_ids = vms.collect {|vm| vm.id}
    return_hash = { :id => id,
      :type => self[:type],
      :text => display_name,
      :name => display_name,
      :size => size_in_gb,
      :available => ((vm_ids.empty?) or
                    (vm_to_include and vm_to_include.id and
                     vm_ids.include?(vm_to_include.id))),
      :create_volume => supports_lvm_subdivision,
      :selected => (!vm_ids.empty? and vm_to_include and vm_to_include.id and
                   (vm_ids.include?(vm_to_include.id)))}
    if lvm_storage_pool
      if return_hash[:available]
        return_hash[:available] = lvm_storage_pool.storage_volumes.full_vm_list.empty?
      end
      conditions = nil
      unless include_used
        conditions = "vms.id is null"
        if (vm_to_include and vm_to_include.id)
          conditions +=" or vms.id=#{vm_to_include.id}"
        end
      end
      if filter_unavailable
        availability_conditions = "storage_volumes.state = '#{StoragePool::STATE_AVAILABLE}'"
        if conditions.nil?
          conditions = availability_conditions
        else
          conditions ="(#{conditions}) and (#{availability_conditions})"
        end
      end
      return_hash[:children] = lvm_storage_pool.storage_volumes.find(:all,
                               :include => :vms,
                               :conditions => conditions).collect do |volume|
        volume.storage_tree_element(params)
      end
    else
      return_hash[:children] = []
    end
    return_hash
  end

end
