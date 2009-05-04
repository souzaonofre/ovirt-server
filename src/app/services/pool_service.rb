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

  def svc_show(pool_id)
    # from before_filter
    @pool = Pool.find(pool_id)
    authorized!(Privilege::VIEW,@pool)
  end

  def update_perms
    set_perms(@pool)
  end
  def additional_update_actions(pool, pool_hash)
  end

  def svc_update(pool_id, pool_hash)
    # from before_filter
    @pool = Pool.find(params[:id])
    @parent = @pool.parent
    update_perms
    authorized!(Privilege::MODIFY)
    Pool.transaction do
      additional_update_actions(@pool, pool_hash)
      @pool.update_attributes!(pool_hash)
    end
  end

  def svc_destroy(pool_id)
    # from before_filter
    @pool = Pool.find(pool_id)
    authorized!(Privilege::MODIFY, @pool)
    check_destroy_preconditions
    @pool.destroy
    return "Pool was successfully deleted."
  end

  def check_destroy_preconditions
  end
end
