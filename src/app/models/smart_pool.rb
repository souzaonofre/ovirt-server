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

class SmartPool < Pool
  has_many :smart_pool_tags, :dependent => :destroy
  has_many :tagged_pools, :through => :smart_pool_tags, :source => :pool,
                   :conditions => "smart_pool_tags.tagged_type = 'Pool'"
  has_many :tagged_storage_pools, :through => :smart_pool_tags,
                           :source => :storage_pool,
                   :conditions => "smart_pool_tags.tagged_type = 'StoragePool'"
  has_many :tagged_hosts, :through => :smart_pool_tags, :source => :host,
                   :conditions => "smart_pool_tags.tagged_type = 'Host'"
  has_many :tagged_vms,   :through => :smart_pool_tags, :source => :vm,
                   :conditions => "smart_pool_tags.tagged_type = 'Vm'"


  def get_type_label
    "Smart Pool"
  end

  def create_for_user(user)
    create_with_parent(DirectoryPool.get_or_create_user_root(user))
  end

  def add_item(item)
    begin
      tag = SmartPoolTag.new(:smart_pool => self, :tagged => item)
      tag.save!
    rescue ActiveRecord::RecordInvalid
      # this is thrown if the tagged item already belongs to the smart pool
      # this operation should be a no-op rather than an error
    end
  end
  def remove_item(item)
    smart_pool_tags.find(:first, :conditions=> {
                                  :tagged_type=>item.class.base_class.to_s,
                                  :tagged_id=>item.id}).destroy
  end

  def self.smart_pools_for_user(user)
    nested_pools = DirectoryPool.get_smart_root.full_set_nested(
                       :privilege => Privilege::MODIFY, :user => user,
                       :smart_pool_set => true)[0][:children]
    user_pools = []
    other_pools = []
    if nested_pools
      nested_pools.each do |pool_element|
        pool = pool_element[:obj]
        if pool.hasChildren
          if pool.name == user
            pool_element[:children].each do |child_element|
              child_pool = child_element[:obj]
              user_pools <<[child_pool.name, child_pool.id]
            end
          else
            if pool_element.has_key?(:children)
              pool_element[:children].each do |child_element|
                child_pool = child_element[:obj]
                other_pools << [pool.name + " > " + child_pool.name, child_pool.id]
              end
            end
          end
        end
      end
    end
    user_pools[-1] << "break" unless user_pools.empty?
    user_pools + other_pools
  end

  # params accepted:
  # :vm_to_include - if specified, storage used by this VM is included in the tree
  # :filter_unavailable - if true, don't include Storage not currently available
  # :include_used - include all storage pools/volumes, even those in use
  # for smart pools,  filter_unavailable defaults to false and include_used to true
  def storage_tree(params = {})
    vm_to_include=params.fetch(:vm_to_include, nil)
    filter_unavailable = params.fetch(:filter_unavailable, false)
    include_used = params.fetch(:include_used, true)
    conditions = "type != 'LvmStoragePool'"
    if filter_unavailable
      conditions = "(#{conditions}) and (storage_pools.state = '#{StoragePool::STATE_AVAILABLE}')"
    end
    tagged_storage_pools.find(:all,
                    :conditions => conditions).collect do |pool|
      pool.storage_tree_element(params)
    end
  end

end
