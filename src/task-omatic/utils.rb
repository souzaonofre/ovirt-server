require 'rexml/document'
include REXML

def String.random_alphanumeric(size=16)
  s = ""
  size.times { s << (i = Kernel.rand(62); i += ((i < 10) ? 48 : ((i < 36) ? 55 : 61 ))).chr }
  s
end

def all_storage_pools(conn)
  all_pools = conn.list_defined_storage_pools
  all_pools.concat(conn.list_storage_pools)
  return all_pools
end

def get_libvirt_pool_from_volume(db_volume)
  phys_volume = StorageVolume.find(:first, :conditions =>
                                   [ "lvm_pool_id = ?", db_volume.storage_pool_id])

  return LibvirtPool.factory(phys_volume.storage_pool)
end

class LibvirtPool
  def initialize(type, name = nil)
    @remote_pool = nil
    @build_on_start = true
    @remote_pool_defined = false
    @remote_pool_started = false

    if name == nil
      @name = type + "-" + String.random_alphanumeric
    else
      @name = name
    end

    @xml = Document.new
    @xml.add_element("pool", {"type" => type})

    @xml.root.add_element("name").add_text(@name)

    @xml.root.add_element("source")

    @xml.root.add_element("target")
    @xml.root.elements["target"].add_element("path")
  end

  def connect(conn)
    all_storage_pools(conn).each do |remote_pool_name|
      tmppool = conn.lookup_storage_pool_by_name(remote_pool_name)

      if self.xmlequal?(Document.new(tmppool.xml_desc).root)
        @remote_pool = tmppool
        break
      end
    end

    if @remote_pool == nil
      @remote_pool = conn.define_storage_pool_xml(@xml.to_s)
      # we need this because we don't want to "build" LVM pools, which would
      # destroy existing data
      if @build_on_start
        @remote_pool.build
      end
      @remote_pool_defined = true
    end

    if @remote_pool.info.state == Libvirt::StoragePool::INACTIVE
      # only try to start the pool if it is currently inactive; in all other
      # states, assume it is already running
      @remote_pool.create
      @remote_pool_started = true
    end
  end

  def list_volumes
    return @remote_pool.list_volumes
  end

  def lookup_vol_by_path(dev)
    return @remote_pool.lookup_volume_by_path(dev)
  end

  def lookup_vol_by_name(name)
    return @remote_pool.lookup_volume_by_name(name)
  end

  def create_vol_xml(xml)
    return @remote_pool.create_vol_xml(xml)
  end

  def shutdown
    if @remote_pool_started
      @remote_pool.destroy
    end
    if @remote_pool_defined
      @remote_pool.undefine
    end
  end

  def xmlequal?(docroot)
    return false
  end

  def self.factory(pool)
    if pool[:type] == "IscsiStoragePool"
      return IscsiLibvirtPool.new(pool.ip_addr, pool[:target])
    elsif pool[:type] == "NfsStoragePool"
      return NFSLibvirtPool.new(pool.ip_addr, pool.export_path)
    elsif pool[:type] == "LvmStoragePool"
      return LVMLibvirtPool.new(pool.vg_name)
    else
      raise "Unknown storage pool type " + pool[:type].to_s
    end
  end
end

class IscsiLibvirtPool < LibvirtPool
  def initialize(ip_addr, target)
    super('iscsi')

    @type = 'iscsi'
    @ipaddr = ip_addr
    @target = target

    @xml.root.elements["source"].add_element("host", {"name" => @ipaddr})
    @xml.root.elements["source"].add_element("device", {"path" => @target})

    @xml.root.elements["target"].elements["path"].text = "/dev/disk/by-id"
  end

  def xmlequal?(docroot)
    return (docroot.attributes['type'] == @type and
            docroot.elements['source'].elements['host'].attributes['name'] == @ipaddr and
            docroot.elements['source'].elements['device'].attributes['path'] == @target)
  end
end

class NFSLibvirtPool < LibvirtPool
  def initialize(ip_addr, export_path)
    super('netfs')

    @type = 'netfs'
    @host = ip_addr
    @remote_path = export_path
    @name = String.random_alphanumeric

    @xml.root.elements["source"].add_element("host", {"name" => @host})
    @xml.root.elements["source"].add_element("dir", {"path" => @remote_path})
    @xml.root.elements["source"].add_element("format", {"type" => "nfs"})

    @xml.root.elements["target"].elements["path"].text = "/mnt/" + @name
  end

  def xmlequal?(docroot)
    return (docroot.attributes['type'] == @type and
            docroot.elements['source'].elements['host'].attributes['name'] == @host and
            docroot.elements['source'].elements['dir'].attributes['path'] == @remote_path)
  end
end

class LVMLibvirtPool < LibvirtPool
  def initialize(vg_name)
    super('logical', vg_name)

    @type = 'logical'
    @build_on_start = false

    @xml.root.elements["source"].add_element("name").add_text(@name)

    @xml.root.elements["target"].elements["path"].text = "/dev/" + @name
  end

  def xmlequal?(docroot)
    return (docroot.attributes['type'] == @type and
            docroot.elements['name'].text == @name and
            docroot.elements['source'].elements['name'] == @name)
  end
end
