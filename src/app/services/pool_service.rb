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
# Mid-level API: Business logic around pools
module PoolService

  include ApplicationService

  # Load the Pool with +id+ for viewing
  #
  # === Instance variables
  # [<tt>@pool</tt>] stores the Pool with +id+
  # [<tt>@parent</tt>] stores the parent of <tt>@pool</tt>
  # === Required permissions
  # [<tt>Privilege::VIEW</tt>] for the pool
  def svc_show(id)
    lookup(id, Privilege::VIEW)
  end

  # Load the Pool with +id+ for editing
  #
  # === Instance variables
  # [<tt>@pool</tt>] stores the Pool with +id+
  # [<tt>@parent</tt>] stores the parent of <tt>@pool</tt>
  # === Required permissions
  # [<tt>Privilege::MODIFY</tt>] for the pool
  def svc_modify(id)
    lookup(id, Privilege::MODIFY)
  end

  def additional_update_actions(pool, pool_hash)
  end

  # Update attributes for the Pool with +id+
  #
  # === Instance variables
  # [<tt>@pool</tt>] stores the Pool with +id+
  # [<tt>@parent</tt>] stores the parent of <tt>@pool</tt>
  # === Required permissions
  # [<tt>Privilege::MODIFY</tt>] for the pool
  def svc_update(id, pool_hash)
    svc_modify(id)
    Pool.transaction do
      additional_update_actions(@pool, pool_hash)
      @pool.update_attributes!(pool_hash)
    end
  end

  # Load a new  Pool for creating
  #
  # === Instance variables
  # [<tt>@pool</tt>] loads a new Pool object into memory
  # [<tt>@parent</tt>] stores the parent of <tt>@pool</tt> as specified by
  #                    +parent_id+
  # === Required permissions
  # [<tt>Privilege::MODIFY</tt>] for the parent pool
  def svc_new(parent_id, attributes=nil)
    @parent = Pool.find(parent_id)
    authorized!(Privilege::MODIFY, @parent)
  end

  alias_method :pool_new, :svc_new

  # Destroy the Pool object with +id+
  #
  # === Instance variables
  # [<tt>@pool</tt>] the destroyed pool
  # [<tt>@parent</tt>] stores the parent of <tt>@pool</tt>
  # === Required permissions
  # [<tt>Privilege::MODIFY</tt>] for the pool
  def svc_destroy(id)
    svc_modify(id)
    check_destroy_preconditions
    @pool.destroy
    return "Pool was successfully deleted."
  end

  def check_destroy_preconditions
  end

  protected
  def lookup(id, priv, use_parent_perms=false)
    @pool = Pool.find(id)
    @parent = @pool.parent
    @current_pool_id = @pool.id if use_parent_perms
    authorized!(priv, use_parent_perms ? @parent : @pool)
  end
end
