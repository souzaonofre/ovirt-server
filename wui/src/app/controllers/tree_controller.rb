class TreeController < ApplicationController
  
  def fetch_nav
    @pools = HardwarePool.get_default_pool.full_set_nested(:method => :json_hash_element)
  end
  
  def fetch_json
    render :json => HardwarePool.get_default_pool.full_set_nested(:method => :json_hash_element).to_json
  end
end
