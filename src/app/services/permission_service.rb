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
# Mid-level API: Business logic around individual permissions
module PermissionService

  include ApplicationService

  # Load the Permission with +id+ for viewing
  #
  # === Instance variables
  # [<tt>@permission</tt>] stores the Permission with +id+
  # === Required permissions
  # [<tt>Privilege::PERM_VIEW</tt>] on permission's Pool
  def svc_show(id)
    lookup(id,Privilege::PERM_VIEW)
  end

  # Load the Permission with +id+ for editing
  #
  # === Instance variables
  # [<tt>@permission</tt>] stores the Permission with +id+
  # === Required permissions
  # [<tt>Privilege::PERM_SET</tt>] on permission's Pool
  def svc_modify(id)
    lookup(id,Privilege::PERM_SET)
  end

  # Load a new Permission for creating
  #
  # === Instance variables
  # [<tt>@permission</tt>] loads a new Permission object into memory
  # === Required permissions
  # [<tt>Privilege::PERM_SET</tt>] for the permission's Pool as specified by
  #                              +pool_id+
  def svc_new(pool_id)
    @permission = Permission.new( { :pool_id => pool_id})
    authorized!(Privilege::PERM_SET,@permission.pool)
  end

  # Save a new Permission record
  #
  # === Instance variables
  # [<tt>@permission</tt>] the newly saved Permission record
  # === Required permissions
  # [<tt>Privilege::PERM_SET</tt>] for the permission's Pool
  def svc_create(perm_hash)
    @permission = Permission.new(perm_hash)
    authorized!(Privilege::PERM_SET, @permission.pool)
    @permission.save_with_new_children
    return "created User Permissions for  #{@permission.uid}."
  end

  # Destroys for the Permission with +id+
  #
  # === Instance variables
  # [<tt>@permission</tt>] stores the Permission with +id+
  # === Required permissions
  # [<tt>Privilege::PERM_SET</tt>] for the Permission's Pool
  def svc_destroy(id)
    lookup(id,Privilege::PERM_SET)
    @permission.destroy
    return "Permission record was successfully deleted."
  end

  #  Updates the role for a user permission.
  #
  # === Instance variables
  # [<tt>@permission</tt>] stores the Permission with +id+
  # === Required permissions
  # [<tt>Privilege::PERM_SET</tt>] for the Permission's Pool
  def svc_update_role(id, role_id)
    lookup(id,Privilege::PERM_SET)
    unless @permission.update_role(role_id)
      raise ActionError.new("Inherited permissions cannot be modified directly.")
    end
    return "User Role updated for permission record"
  end

  private
  def lookup(id, priv)
    @permission = Permission.find(id)
    authorized!(priv,@permission.pool)
  end

end
