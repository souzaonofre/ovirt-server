#
# Copyright (C) 2009 Red Hat, Inc.
# Written by Jason Guiditta <jguiditt@redhat.com>
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

class Cloud::CloudController < ApplicationController
  include VmService

  layout 'cloud/cloud'

  before_filter :set_vars

  protected

  # Override the default in ApplicationController, cloud has its own
  # template for rendering these errors
  def html_error_page(title, msg)
    flash[:error] = msg
    redirect_to params
  end

  # Override the default in ApplicationController, cloud has its own
  # way of handling these (hooked into VmService::svc_vm_actions
  def handle_partial_success_error(error)
    handle_error(:error => error, :status => :ok,
                 :message => {:summary => error.message,
                              :failures => error.failures,
                              :successes => error.successes},
                 :title => "Some actions failed")
  end

  # NOTE: This probably will/should be moved to use set_perms in
  # ApplicationService once that is ready to go. Only problem with that
  # idea is that there is currently no before filter to make sure that
  # gets called.
  def set_vars
    @user = get_login_user
  end
end
