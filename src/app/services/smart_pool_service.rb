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

  # Load a new SmartPool for creating
  #
  # === Instance variables
  # [<tt>@pool</tt>] loads a new SmartPool object into memory
  # [<tt>@parent</tt>] stores the parent of <tt>@pool</tt> as specified by
  #                    +parent_id+
  # === Required permissions
  # [<tt>Privilege::MODIFY</tt>] for the pool
  def svc_new(parent_id, attributes=nil)
    @pool = SmartPool.new(attributes)
    super(parent_id)
  end

  # Save a new SmartPool
  #
  # === Instance variables
  # [<tt>@pool</tt>] the newly saved SmartPool
  # [<tt>@parent</tt>] stores the parent of <tt>@pool</tt> as specified by
  #                    +parent_id+
  # === Required permissions
  # [<tt>Privilege::MODIFY</tt>] for the pool
  def svc_create(pool_hash, other_args)
    svc_new(nil, pool_hash)
    @pool.create_with_parent(@parent)
    return "Smart Pool was successfully created."
  end

  # Add or remove (depending on +item_action+) objects represneted by
  # +resource_ids+ in the smart pool identified by +pool_id+. Item type
  # is identified by +item_class+. If +item_class+ is nil, then
  # +resource_ids+ is an array of [class, id] pairs.
  #
  # === Instance variables
  # [<tt>@pool</tt>] the current SmartPool
  # [<tt>@parent</tt>] the parent of <tt>@pool</tt>
  # === Required permissions
  # [<tt>Privilege::MODIFY</tt>] for the current smart pool
  # [<tt>Privilege::VIEW</tt>] for any item being added to this smart pool
  def svc_add_remove_items(pool_id, item_class, item_action, resource_ids)
    svc_modify(pool_id)
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
