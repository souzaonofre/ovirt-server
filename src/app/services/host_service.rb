#--
# Copyright (C) 2009 Red Hat, Inc.
# Written by David Lutterkort <lutter@redhat.com>
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
#++
# Business logic around hosts aka nodes
module HostService

  include ApplicationService

  # Host attributes on which we filter with '='
  EQ_ATTRIBUTES = [ :state, :arch, :hostname, :uuid,
                    :hardware_pool_id ]

  # List hosts matching criteria described by +params+; only the entries
  # for keys in +EQ_ATTRIBUTES+ are used
  #
  # === Instance variables
  # [<tt>@hosts</tt>] stores list of hosts matching criteria
  # === Required permissions
  # [<tt>Privilege::VIEW</tt>] no exception raised, <tt>@hosts</tt>
  #                            is filtered by privilege
  def svc_list(params)
    conditions = []
    EQ_ATTRIBUTES.each do |attr|
      if params[attr]
        conditions << "hosts.#{attr} = :#{attr}"
      end
    end
    # Add permission check
    params = params.dup
    params[:user] = get_login_user
    params[:priv] = Privilege::VIEW
    conditions << "privileges.name=:priv"
    conditions << "permissions.uid=:user"
    incl = [{ :hardware_pool => { :permissions => { :role => :privileges}}}]
    @hosts = Host.find(:all,
                       :include => incl,
                       :conditions => [conditions.join(" and "), params],
                       :order => "hosts.id")
  end

  # Load the Host with +id+ for viewing
  #
  # === Instance variables
  # [<tt>@host</tt>] stores the Host with +id+
  # === Required permissions
  # [<tt>Privilege::VIEW</tt>] on host's HardwarePool
  def svc_show(id)
    lookup(id, Privilege::VIEW)
  end

  # Load the Host with +id+ for editing
  #
  # === Instance variables
  # [<tt>@host</tt>] stores the Host with +id+
  # === Required permissions
  # [<tt>Privilege::MODIFY</tt>] on host's HardwarePool
  def svc_modify(id)
    lookup(id, Privilege::MODIFY)
  end

  # Set the disabled state of the Host with +id+ to <tt>:enabled</tt>
  # or <tt>:disabled</tt>
  #
  # === Instance variables
  # [<tt>@host</tt>] stores the Host with +id+
  # === Required permissions
  # [<tt>Privilege::MODIFY</tt>] on host's HardwarePool
  def svc_enable(id, state)
    ind = ["enabled", "disabled"].index(state.to_s)
    if ind.nil?
      raise ArgumentError, "STATE must be 'enabled' or 'disabled'"
    end
    svc_modify(id)
    @host.is_disabled = ind
    @host.save!
  end

  # Queue task to migrate all VM's off the Host with +id+, and mark the
  # host as disabled
  #
  # === Instance variables
  # [<tt>@host</tt>] stores the Host with +id+
  # === Required permissions
  # [<tt>Privilege::MODIFY</tt>] on host's HardwarePool
  def svc_clear_vms(id)
    svc_modify(id)
    Host.transaction do
      task = HostTask.new({ :user        => get_login_user,
                            :task_target => @host,
                            :action      => HostTask::ACTION_CLEAR_VMS,
                            :state       => Task::STATE_QUEUED})
      task.save!
      @host.is_disabled = true
      @host.save!
    end
  end

  private
  def lookup(id, priv)
    @host = Host.find(id)
    authorized!(priv, @host.hardware_pool)
  end
end
