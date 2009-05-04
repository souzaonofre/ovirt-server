#
# Copyright (C) 2009 Red Hat, Inc.
# Written by Scott Seago <sseago@redhat.com>,
#            David Lutterkort <lutter@redhat.com>
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
# Mid-level API: Business logic around smart pools
module SmartPoolService

  include PoolService

  def svc_create(pool_hash, other_args)
    # from before_filter
    @pool = SmartPool.new(pool_hash)
    @parent = DirectoryPool.get_or_create_user_root(get_login_user)
    authorized!(Privilege::MODIFY,@parent)

    alert = "Smart Pool was successfully created."
    @pool.create_with_parent(@parent)
    return alert
  end

  # if item_class is nil, resource_ids is an array of [class, id] pairs
  def svc_add_remove_items(pool_id, item_class, item_action, resource_ids)
    # from before_filter
    @pool = SmartPool.find(pool_id)
    @parent = @pool.parent
    authorized!(Privilege::MODIFY,@pool)
    unless [:add, :remove].include?(item_action)
      raise ActionError.new("Invalid action #{item_action}")
    end
    if item_class
      resources = item_class.find(resource_ids)
    else
      resources = resource_ids.collect {|the_class,id| the_class.find(id)}
    end

    # relay error message if movable check fails for any resource
    success = true
    failed_resources = {}
    successful_resources = []
    resources.each do |resource|
      begin
        if item_action == :add
          if ! resource.permission_obj.can_view(@user)
            failed_resources[resource] = "Failed permission check"
          else
            @pool.add_item(resource)
            successful_resources << resource
          end
        elsif item_action == :remove
          @pool.remove_item(resource)
          successful_resources << resource
        end
      rescue Exception => ex
        failed_resources[resource] = ex.message
      end
    end
    unless failed_resources.empty?
      raise PartialSuccessError.new("#{item_action.to_s} #{item_class.table_name.humanize if item_class} only partially successful",
                                    failed_resources, successful_resources)
    end
    return "#{item_action.to_s} #{item_class.table_name.humanize} successful."
  end

end
