class UsagesController < ApplicationController
  include UsageService

  def create
    usage = svc_create(params[:usage])
    render :json => { :success => true, :data => usage }
  end

  def remove
    removed_ids = svc_destroy_all(params[:ids])
    render :json => { :success => true, :removed => removed_ids }
  end
end
