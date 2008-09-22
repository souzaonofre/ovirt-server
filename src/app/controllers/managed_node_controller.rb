#
# Copyright (C) 2008 Red Hat, Inc.
# Written by Darryl L. Pierce <dpierce@redhat.com>
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation; version 2 of the License.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
# details.
#
# You should have received a copy of the GNU General Public License along with
# this program; if not, write to the Free Software Foundation, Inc., 51 Franklin
# Street, Fifth Floor, Boston, MA  02110-1301, USA.  A copy of the GNU General
# Public License is also available at http://www.gnu.org/copyleft/gpl.html.

# +ManagedNodeController+ provides methods for interacting over HTTP with a
# managed node.
#
class ManagedNodeController < ApplicationController
  before_filter :load_host, :only => :config
  before_filter :load_macs, :only => :config

  def is_logged_in
    # this overrides the default which is to force the client to log in
  end

  # Generates a configuration file for the managed node.
  #
  def config
    context = ManagedNodeConfiguration.generate(@host, @macs)

    send_data("#{context}", :type => 'text', :disposition => 'inline')
  end

  def error
    send_data("#{flash[:message]}", :type => 'text', :disposition => 'inline')
  end

  private

  def load_host
    @host = Host.find_by_hostname(params[:host])

    render :nothing => true, :status => :error unless @host
  end

  def load_macs
    @macs = Hash.new
    mac_text = params[:macs]

    if mac_text != nil
      mac_text.scan(/([^,]+)\,?/).each do |line|
        key, value = line.first.split("=")
        @macs[key] = value
      end
    end

    render :nothing => true, :status => :error if @macs.empty?
  end
end
