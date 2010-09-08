module UsageService
  include ApplicationService

  def authorize
    authorized!(Privilege::MODIFY,HardwarePool.get_default_pool)
  end

  def svc_create(usage_hash)
    authorize
    usage_hash[:id] = Usage.maximum(:id) + 1
    @usage = Usage.new(usage_hash)
    @usage.save!
    return @usage
  end

  def svc_destroy_all(ids)
    authorize
    # prevent destruction of original usages (1, 2 and 3)
    ids -= ['1','2','3']
    Usage.destroy(ids)
    return ids
  end
end
