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
# Mid-level API: Business logic around nics
module NicService
  include ApplicationService

  # Load the Nic with +id+ for viewing
  #
  # === Instance variables
  # [<tt>@nic</tt>] stores the Nic with +id+
  # === Required permissions
  # [<tt>Privilege::VIEW</tt>] on nic target's Pool
  def svc_show(id)
    lookup(id,Privilege::VIEW)
  end

  private
  def lookup(id, priv)
    @nic = Nic.find(id)
    authorized!(priv,@nic.host.hardware_pool)
  end

end
