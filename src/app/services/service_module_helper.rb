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


# This module is used to bootstrap testing for the service api,
# which depends on certain methods existing in the class which includes it.
# Clearly this is not the case with unit tests on the modules themselves,
# so any dependencies are set up here.
module ServiceModuleHelper

  def get_login_user
    return @user
  end

  def set_login_user(user=nil)
    @user = user
  end
end