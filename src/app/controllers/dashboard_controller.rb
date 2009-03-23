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

class DashboardController < ApplicationController

  include TaskActions
  def tasks_query_obj
    Task
  end
  def tasks_conditions
    {:user => get_login_user}
  end

  def index
    @task_types = Task::TASK_TYPES_OPTIONS
    @user = get_login_user
    show_tasks
  end

  def show
    respond_to do |format|
      format.html {
        render :layout => 'tabs-and-content' if params[:ajax]
        render :layout => 'help-and-content' if params[:nolayout]
      }
      format.xml {
        render :xml => @pool.to_xml(XML_OPTS)
      }
    end
  end

  def tasks_internal
    @task_type = params[:task_type]
    @task_type ||=""
    super
  end

end
