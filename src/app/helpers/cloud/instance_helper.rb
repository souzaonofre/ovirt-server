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

module Cloud::InstanceHelper
#  TODO: add checking to make sure this is a symbol, possibly as simple as adding a
#   to_sym, just not sure what happens if it is already a symbol
  def sort_td_class_helper(param, key = :sort)
    result = 'sortup' if params[key] == param
    result = 'sortdown' if params[key] == param + " DESC"
    return result
  end

  # pass in an optional symbol for the key you want to use
  # TODO: add checking to make sure this is a symbol, possibly as simple as adding a
  # to_sym, just not sure what happens if it is already a symbol
  def sort_link_helper(text, param, key = :sort)
    param += " DESC" if params[key] == param
    param_list = params.clone
    param_list[key] == param ? param_list[key] = param += " DESC": param_list[key] = param
    link_to(text, :action => 'index', :params => param_list)
  end
end
