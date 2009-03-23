#
# Copyright (C) 2009 Red Hat, Inc.
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
module TaskActions
  def show_tasks
    @task_states = Task::TASK_STATES_OPTIONS
    params[:page]=1
    params[:sortname]="tasks.created_at"
    params[:sortorder]="desc"
    @tasks = tasks_internal
    show
  end

  def tasks
    render :json => tasks_internal.to_json
  end

  def tasks_internal
    @task_state = params[:task_state]
    @task_state ||=Task::STATE_QUEUED
    @task_type = params[:task_type]
    @task_type ||=""
    conditions = tasks_conditions
    conditions[:type] = @task_type unless @task_type.empty?
    conditions[:state] = @task_state unless @task_state.empty?
    find_opts = {:include => [:storage_pool, :host, :vm]}
    find_opts[:conditions] = conditions unless conditions.empty?
    attr_list = []
    attr_list << :id if params[:checkboxes]
    attr_list += [:type_label, :task_obj, :action_with_args, :message, :state, :user, :created_at]
    json_hash(tasks_query_obj, attr_list, [:all], find_opts)
  end


end
