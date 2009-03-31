#
# Copyright (C) 2008 Red Hat, Inc.
# Written by Darryl L. Pierce <dpierce@redhat.com>
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

require File.dirname(__FILE__) + '/../test_helper'

class ManagedNodeControllerTest < ActionController::TestCase
  fixtures :bonding_types
  fixtures :bondings
  fixtures :bondings_nics
  fixtures :hosts
  fixtures :nics

  # Ensures the request succeeds if it is well-formed.
  #
  def test_config
    get :config,
      {
      :host => hosts(:mailservers_managed_node).hostname,
      :macs => "#{nics(:mailserver_nic_one).mac}=eth0}"
    }

    assert_response :success
    assert @response.body.length, "Did not get a response"
  end

end
