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

class StorageVolumeController < ApplicationController
  include StorageVolumeService

  def new
    svc_new(params[:storage_pool_id], params[:source_volume_id])
    @return_to_workflow = params[:return_to_workflow] || false
    render :layout => 'popup'
  end

  def create
    volume = params[:storage_volume]
    unless type = params[:storage_type]
      type = volume.delete(:storage_type)
    end
    alert = svc_create(type, volume)
    respond_to do |format|
      format.json { render :json => { :object => "storage_volume",
          :success => true, :alert => alert,
          :new_volume => @storage_volume.storage_tree_element(
                                {:filter_unavailable => false, :state => 'new'})} }
      format.xml { render :xml => @storage_volume,
        :status => :created,
        :location => storage_pool_url(@storage_volume)
      }
    end
  end

  def show
    svc_show(params[:id])
    respond_to do |format|
      format.html { render :layout => 'selection' }
      format.json do
        attr_list = []
        attr_list << :id if (@storage_pool.user_subdividable and authorized?(Privilege::MODIFY))
        attr_list += [:display_name, :size_in_gb, :get_type_label]
        json_list(@storage_pool.storage_volumes, attr_list)
      end
      format.xml { render :xml => @storage_volume.to_xml }
    end
  end

  def destroy
    alert = svc_destroy(params[:id])
    respond_to do |format|
      format.json { render :json => { :object => "storage_volume",
          :success => true, :alert => alert } }
      format.xml { head(:ok) }
    end
  end

  # FIXME: remove these when service transition is complete. these are here
  # to keep from running permissions checks and other setup steps twice
  def tmp_pre_update
  end
  def tmp_authorize_admin
  end

end
