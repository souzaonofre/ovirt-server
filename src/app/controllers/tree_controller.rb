class TreeController < ApplicationController

  def get_pools
    # TODO: split these into separate hash elements for HW and smart pools
    pools = HardwarePool.get_default_pool.full_set_nested(:method => :json_hash_element,
                       :privilege => Permission::PRIV_VIEW, :user => get_login_user)
    pools += DirectoryPool.get_smart_root.full_set_nested(:method => :json_hash_element,
                       :privilege => Permission::PRIV_VIEW, :user => get_login_user,
                       :smart_pool_set => true)
  end
  def fetch_nav
    @pools = get_pools
  end
  
  def fetch_json
    render :json => get_pools.to_json
  end
end
