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


  def create_for_user(user)
    create_with_parent(DirectoryPool.get_or_create_user_root(user))
  end

  def add_item(item)
    tag = SmartPoolTag.new(:smart_pool => self, :tagged => item)
    tag.save!
  end
  def remove_item(item)
    smart_pool_tags.find(:first, :conditions=> {
                                  :tagged_type=>item.class.base_class.to_s,
                                  :tagged_id=>item.id}).destroy
  end

end
