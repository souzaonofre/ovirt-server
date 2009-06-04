#
# Copyright (C) 2009 Red Hat, Inc.
# Written by Scott Seago <sseago@redhat.com>,
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
# Mid-level API: Business logic around quotas
module QuotaService
  include ApplicationService

  # Load the Quota with +id+ for viewing
  #
  # === Instance variables
  # [<tt>@quota</tt>] stores the Quota with +id+
  # === Required permissions
  # [<tt>Privilege::VIEW</tt>] on quota's Pool
  def svc_show(id)
    lookup(id,Privilege::VIEW)
  end

  # Load the Quota with +id+ for editing
  #
  # === Instance variables
  # [<tt>@quota</tt>] stores the Quota with +id+
  # === Required permissions
  # [<tt>Privilege::MODIFY</tt>] on quota's Pool
  def svc_modify(id)
    lookup(id,Privilege::MODIFY)
  end

  # Update attributes for the Quota with +id+
  #
  # === Instance variables
  # [<tt>@quota</tt>] stores the Quota with +id+
  # === Required permissions
  # [<tt>Privilege::MODIFY</tt>] for the Quota's Pool
  def svc_update(id, quota_hash)
    lookup(id,Privilege::MODIFY)
    @quota.update_attributes!(quota_hash)
    return "Quota was successfully updated."
  end

  # Load a new Quota for creating
  #
  # === Instance variables
  # [<tt>@quota</tt>] loads a new Quota object into memory
  # === Required permissions
  # [<tt>Privilege::MODIFY</tt>] for the quota's Pool as specified by
  #                              +pool_id+
  def svc_new(pool_id)
    @quota = Quota.new( { :pool_id => pool_id})
    authorized!(Privilege::MODIFY,@quota.pool)

  end

  # Save a new Quota
  #
  # === Instance variables
  # [<tt>@quota</tt>] the newly saved quota
  # === Required permissions
  # [<tt>Privilege::MODIFY</tt>] for the quota's Pool as specified by
  #                              +pool_id+
  def svc_create(quota_hash)
    @quota = Quota.new( quota_hash)
    authorized!(Privilege::MODIFY,@quota.pool)
    @quota.save!
    return "Quota was successfully created."
  end

  # Destroys for the Quota with +id+
  #
  # === Instance variables
  # [<tt>@quota</tt>] stores the Quota with +id+
  # === Required permissions
  # [<tt>Privilege::MODIFY</tt>] on quota's Pool
  def svc_destroy(id)
    lookup(id,Privilege::MODIFY)
    @quota.destroy
    return "Quota was successfully deleted."
  end

  private
  def lookup(id, priv)
    @quota = Quota.find(id)
    authorized!(priv,@quota.pool)
  end

end
