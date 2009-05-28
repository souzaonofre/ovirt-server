# Copyright (C) 2008 Red Hat, Inc.
# Written by Chris Lalancette <clalance@redhat.com>
# and Ian Main <imain@redhat.com>
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

require 'libvirt'
require 'rexml/document'
include REXML

def String.random_alphanumeric(size=16)
  s = ""
  size.times { s << (i = Kernel.rand(62); i += ((i < 10) ? 48 : ((i < 36) ? 55 : 61 ))).chr }
  s
end

def get_libvirt_lvm_pool_from_volume(db_volume)
  phys_volume = StorageVolume.find(:first, :conditions =>
                                   ["lvm_pool_id = ?", db_volume.storage_pool_id])

  return LibvirtPool.factory(phys_volume.storage_pool)
end


def task_storage_cobbler_setup(db_vm)

  image_volume = nil

  if (db_vm.boot_device == Vm::BOOT_DEV_CDROM) &&
      db_vm.uses_cobbler? && (db_vm.cobbler_type == Vm::IMAGE_PREFIX)

    details = Cobbler::Image.find_one(db_vm.cobbler_name)
    raise "Image #{vm.cobbler_name} not found in Cobbler server" unless details

    # extract the components of the image filename
    image_uri = details.file
    protocol = auth = ip_addr = export_path = filename = ""

    protocol, image_uri = image_uri.split("://") if image_uri.include?("://")
    auth, image_uri = image_uri.split("@") if image_uri.include?("@")

    # it's ugly, but string.split returns an empty string as the first
    # result here, so we'll just ignore it
    ignored, ip_addr, image_uri =
        image_uri.split(/^([^\/]+)(\/.*)/) unless image_uri =~ /^\//
    ignored, export_path, filename =
        image_uri.split(/^(.*)\/(.+)/)

    found = false

    db_vm.storage_volumes.each do |volume|
      if volume.filename == filename
        if (volume.storage_pool.ip_addr == ip_addr) &&
          (volume.storage_pool.export_path == export_path)
          found = true
        end
      end
    end

    unless found
      # Create a new transient NFS storage volume
      # This volume is *not* persisted.
      image_volume = StorageVolume.factory("NFS", :filename => filename)

      image_volume.storage_pool
      image_pool = StoragePool.factory(StoragePool::NFS)

      image_pool.ip_addr = ip_addr
      image_pool.export_path = export_path
      image_pool.storage_volumes << image_volume
      image_volume.storage_pool = image_pool
    end
  end

  return image_volume
end

class LibvirtPool

  attr_reader :remote_pool

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

  def connect(session, node)
    pools = session.objects(:class => 'pool', 'node' => node.object_id)
    pools.each do |pool|
      result = pool.getXMLDesc
      raise "Error getting xml description of pool: #{result.text}" unless result.status == 0

      xml_desc = result.description
      if self.xmlequal?(Document.new(xml_desc).root)
        @remote_pool = pool
        break
      end
    end

    if @remote_pool == nil
      result = node.storagePoolDefineXML(@xml.to_s, :timeout => 60 * 2)
      raise "Error creating pool: #{result.text}" unless result.status == 0
      @remote_pool = session.object(:object_id => result.pool)
      raise "Error finding newly created remote pool." unless @remote_pool

      # we need this because we don't want to "build" LVM pools, which would
      # destroy existing data
      if @build_on_start
        result = @remote_pool.build(:timeout => 60 * 2)
        raise "Error building pool: #{result.text}" unless result.status == 0
      end
      @remote_pool_defined = true
    end

    # FIXME: I'm not sure.. it seems like there could be other things going on
    # with the storage pool state.  State can be inactive, building, running
    # or degraded.  I think some more thought should go here to make sure
    # we're doing things right in each state.

    if @remote_pool.state == "inactive"
      # only try to start the pool if it is currently inactive; in all other
      # states, assume it is already running
      result = @remote_pool.create(:timeout => 60 * 2)
      raise "Error defining pool: #{result.text}" unless result.status == 0

      # Refresh qpid object with new properties.
      @remote_pool.update

      @remote_pool_started = true
    end

    # Refresh the remote pool requesting that it rescan its volumes.  Putting
    # it here means it will call this every time we connect to a pool from
    # taskomatic.  This includes when starting a VM which is probably the most
    # important time.
    result = @remote_pool.refresh
    puts "Error refreshing storage pool: #{result.text}" unless result.status == 0
  end

  def create_vol(type, name, size, owner, group, mode)
    @vol_xml = Document.new
    @vol_xml.add_element("volume", {"type" => type})
    @vol_xml.root.add_element("name").add_text(name)
    @vol_xml.root.add_element("capacity", {"unit" => "K"}).add_text(size.to_s)
    @vol_xml.root.add_element("target")
    @vol_xml.root.elements["target"].add_element("permissions")
    @vol_xml.root.elements["target"].elements["permissions"].add_element("owner").add_text(owner) if owner
    @vol_xml.root.elements["target"].elements["permissions"].add_element("group").add_text(group) if group
    @vol_xml.root.elements["target"].elements["permissions"].add_element("mode").add_text(mode) if mode
  end

  def shutdown
    if @remote_pool_started
      result = @remote_pool.destroy
    end
    if @remote_pool_defined
      result = @remote_pool.undefine
    end
  end

  def xmlequal?(docroot)
    return false
  end

  def self.factory(pool)
    if pool[:type] == "IscsiStoragePool"
      return IscsiLibvirtPool.new(pool.ip_addr, pool[:target], pool[:port])
    elsif pool[:type] == "NfsStoragePool"
      return NFSLibvirtPool.new(pool.ip_addr, pool.export_path)
    elsif pool[:type] == "LvmStoragePool"
      # OK, if this is LVM storage, there are two cases we need to care about:
      # 1) this is a LUN with LVM already on it.  In this case, all we need to
      #  do is to create a new LV (== libvirt volume), and be done with it
      # 2) this LUN is blank, so there is no LVM on it already.  In this
      #  case, we need to pvcreate, vgcreate first (== libvirt pool build),
      #  and *then* create the new LV (== libvirt volume) on top of that.
      #
      # We can tell the difference between an LVM Pool that exists and one
      # that needs to be created based on the value of the pool.state;
      # if it is PENDING_SETUP, we need to create it first
      phys_volume = StorageVolume.find(:first, :conditions =>
                                       [ "lvm_pool_id = ?", pool.id])
      return LVMLibvirtPool.new(pool.vg_name, phys_volume.path,
                                pool.state == StoragePool::STATE_PENDING_SETUP)
    else
      raise "Unknown storage pool type " + pool[:type].to_s
    end
  end
end

class IscsiLibvirtPool < LibvirtPool
  def initialize(ip_addr, target, port)
    mount = "#{ip_addr}-#{target}-#{port}"
    super('iscsi', mount)

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
    target = "#{ip_addr}-#{export_path.tr('/', '_')}"
    super('netfs', target)

    @type = 'netfs'
    @host = ip_addr
    @remote_path = export_path

    @xml.root.elements["source"].add_element("host", {"name" => @host})
    @xml.root.elements["source"].add_element("dir", {"path" => @remote_path})
    @xml.root.elements["source"].add_element("format", {"type" => "nfs"})

    @xml.root.elements["target"].elements["path"].text = "/mnt/" + @name
  end

  def create_vol(name, size, owner, group, mode)
    # FIXME: this can actually take some time to complete (since we aren't
    # doing sparse allocations at the moment).  During that time, whichever
    # libvirtd we chose to use is completely hung up.  The solution is 3-fold:
    # 1.  Allow sparse allocations in the WUI front-end
    # 2.  Make libvirtd multi-threaded
    # 3.  Make taskomatic multi-threaded
    super("netfs", name, size, owner, group, mode)

    # FIXME: we have to add the format as raw here because of a bug in libvirt;
    # if you specify a volume with no format, it will crash libvirtd
    @vol_xml.root.elements["target"].add_element("format", {"type" => "raw"})

    # FIXME: Add allocation 0 element so that we create a sparse file.
    # This was done because qmf was timing out waiting for the create
    # operation to complete.  This needs to be fixed in a better way
    # however.  We want to have non-sparse files for performance reasons.
    @vol_xml.root.add_element("allocation").add_text('0')

    result = @remote_pool.createVolumeXML(@vol_xml.to_s)
    raise "Error creating remote pool: #{result.text}" unless result.status == 0
    return result.volume
  end

  def xmlequal?(docroot)
    return (docroot.attributes['type'] == @type and
        docroot.elements['source'].elements['host'].attributes['name'] == @host and
        docroot.elements['source'].elements['dir'].attributes['path'] == @remote_path)
  end
end

class LVMLibvirtPool < LibvirtPool
  def initialize(vg_name, device, build_on_start)
    super('logical', vg_name)

    @type = 'logical'
    @build_on_start = build_on_start

    @xml.root.elements["source"].add_element("name").add_text(@name)
    @xml.root.elements["source"].add_element("device", {"path" => device})
    @xml.root.elements["target"].elements["path"].text = "/dev/" + @name
  end

  def create_vol(name, size, owner, group, mode)
    super("logical", name, size, owner, group, mode)
    result = @remote_pool.createVolumeXML(@vol_xml.to_s)
    raise "Error creating remote pool: #{result.text}" unless result.status == 0
    return result.volume
  end

  def xmlequal?(docroot)
    return (docroot.attributes['type'] == @type and
        docroot.elements['name'].text == @name and
        docroot.elements['source'].elements['name'] and
        docroot.elements['source'].elements['name'].text == @name)
  end
end

