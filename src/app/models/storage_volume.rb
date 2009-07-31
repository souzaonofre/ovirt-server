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

  validates_presence_of :storage_pool_id


  validates_numericality_of :size,
     :greater_than_or_equal_to => 0,
     :unless => Proc.new { |storage_volume| storage_volume.nil? }

  validates_inclusion_of :type,
    :in => %w( IscsiStorageVolume LvmStorageVolume NfsStorageVolume GlusterfsStorageVolume )

  STATE_PENDING_SETUP    = "pending_setup"
  STATE_PENDING_DELETION = "pending_deletion"
  STATE_AVAILABLE        = "available"

  validates_inclusion_of :state,
    :in => [ STATE_PENDING_SETUP, STATE_PENDING_DELETION, STATE_AVAILABLE]

  def self.factory(type, params = {})
    params[:state] = STATE_PENDING_SETUP unless params[:state]
    case type
    when StoragePool::ISCSI
      return IscsiStorageVolume.new(params)
    when StoragePool::NFS
      return NfsStorageVolume.new(params)
    when StoragePool::GLUSTERFS
      return GlusterfsStorageVolume.new(params)
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

  def deletable
    storage_pool.user_subdividable and vms.empty? and (lvm_storage_pool.nil? or lvm_storage_pool.storage_volumes.empty?)
  end

  #--
  #TODO: the following two methods should be moved out somewhere, perhaps an 'acts_as' plugin?
  #Though ui_parent will have class specific impl
  #++
  ##This is a convenience method for use in the ui to simplify creating a unigue id for placement/retrieval
  #in/from the DOM.  This was added because there is a chance of duplicate ids between different object types,
  #and multiple object type will appear concurrently in the ui.  The combination of type and id should be unique.
  def ui_object
    self.class.to_s + '_' + id.to_s
  end

  #This is a convenience method for use in the processing and manipulation of json in the ui.
  #This serves as a key both for determining where to attached elements in the DOM and quickly
  #accessing and updating a cached object on the client.
  def ui_parent
    storage_pool[:type].to_s + '_' + storage_pool_id.to_s
  end

  def storage_tree_element(params = {})
    vm_to_include=params.fetch(:vm_to_include, nil)
    filter_unavailable = params.fetch(:filter_unavailable, true)
    include_used = params.fetch(:include_used, false)
    vm_ids = vms.collect {|vm| vm.id}
    state = params.fetch(:state,'new')
    return_hash = { :id => id,
      :type => self[:type],
      :ui_object => ui_object,
      :state => state,
      :name => display_name,
      :size => size_in_gb,
      :available => ((vm_ids.empty?) or
                    (vm_to_include and vm_to_include.id and
                     vm_ids.include?(vm_to_include.id))),
      :create_volume => supports_lvm_subdivision,
      :ui_parent => ui_parent,
      :selected => (!vm_ids.empty? and vm_to_include and vm_to_include.id and
                   (vm_ids.include?(vm_to_include.id))),
      :is_pool => false}
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
        availability_conditions = "(storage_volumes.state = '#{StoragePool::STATE_AVAILABLE}'
        or storage_volumes.state = '#{StoragePool::STATE_PENDING_SETUP}')"
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

  def permission_obj
    storage_pool.hardware_pool
  end

  def movable?
     if vms.size > 0 or
         (not lvm_storage_pool.nil? and not lvm_storage_pool.movable?)
           return false
     end
     return true
  end

end
