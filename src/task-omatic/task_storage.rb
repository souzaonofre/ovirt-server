# Copyright (C) 2008 Red Hat, Inc.
# Written by Chris Lalancette <clalance@redhat.com>
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

require 'utils'

require 'libvirt'

def build_libvirt_vol_xml(name, size, owner, group, mode)
  vol_xml = Document.new
  vol_xml.add_element("volume", {"type" => "logical"})
  vol_xml.root.add_element("name").add_text(name)
  vol_xml.root.add_element("capacity", {"unit" => "K"}).add_text(size.to_s)
  vol_xml.root.add_element("target")
  vol_xml.root.elements["target"].add_element("permissions")
  vol_xml.root.elements["target"].elements["permissions"].add_element("owner").add_text(owner)
  vol_xml.root.elements["target"].elements["permissions"].add_element("group").add_text(group)
  vol_xml.root.elements["target"].elements["permissions"].add_element("mode").add_text(mode)

  return vol_xml
end

def add_volumes_to_db(db_pool, libvirt_pool, owner = nil, group = nil, mode = nil)
  # FIXME: this is currently broken if you do something like:
  # 1.  Add an iscsi pool with 3 volumes (lun-1, lun-2, lun-3)
  # 2.  Scan it in
  # 3.  Remove lun-3 from the pool
  # 4.  Re-scan it
  # What will happen is that you will still have lun-3 available in the
  # database, even though it's not available in the pool anymore.  It's a
  # little tricky, though; we have to make sure that we don't pull the
  # database entry out from underneath a possibly running VM (or do we?)
  libvirt_pool.list_volumes.each do |volname|
    storage_volume = StorageVolume.factory(db_pool.get_type_label)

    # NOTE: it is safe (and, in fact, necessary) to use
    # #{storage_volume.volume_name} here without sanitizing it.  This is
    # because this is *not* based on user modifiable data, but rather, on an
    # internal implementation detail
    existing_vol = StorageVolume.find(:first, :conditions =>
                                      [ "storage_pool_id = ? AND #{storage_volume.volume_name} = ?",
                                        db_pool.id, volname])
    if existing_vol != nil
      # in this case, this path already exists in the database; just skip
      next
    end

    volptr = libvirt_pool.lookup_vol_by_name(volname)

    volinfo = volptr.info

    storage_volume = StorageVolume.factory(db_pool.get_type_label)
    storage_volume.path = volptr.path
    storage_volume.size = volinfo.capacity / 1024
    storage_volume.storage_pool_id = db_pool.id
    storage_volume.write_attribute(storage_volume.volume_name, volname)
    storage_volume.lv_owner_perms = owner
    storage_volume.lv_group_perms = group
    storage_volume.lv_mode_perms = mode
    storage_volume.save
  end
end

def storage_find_suitable_host(pool_id)
  # find all of the hosts in the same pool as the storage
  hosts = Host.find(:all, :conditions =>
                    [ "hardware_pool_id = ?", pool_id ])

  conn = nil
  hosts.each do |host|
    begin
      # FIXME: this can actually hang up taskomatic for quite some time.  To
      # see how, make one of your remote servers do "iptables -I INPUT -j DROP"
      # and then try to run this; it will take TCP quite a while to give up.
      # Unfortunately the solution is probably to do some sort of threading
      conn = Libvirt::open("qemu+tcp://" + host.hostname + "/system")

      # if we didn't raise an exception, we connected; get out of here
      break
    rescue Libvirt::ConnectionError
      # if we couldn't connect for whatever reason, just try the next host
      next
    end
  end

  if conn == nil
    # last ditch effort; if we didn't find any hosts, just use ourselves.
    # this may or may not work
    begin
      conn = Libvirt::open("qemu:///system")
    rescue
    end
  end

  if conn == nil
    raise "Could not find a host to scan storage"
  end

  return conn
end

# The words "pool" and "volume" are ridiculously overloaded in our context.
# Therefore, the refresh_pool method adopts this convention:
# phys_db_pool: The underlying physical storage pool, as it is represented in
#               the database
# phys_libvirt_pool: The underlying physical storage, as it is represented in
#                    libvirt
# lvm_db_pool: The logical storage pool (if it exists), as it is represented
#              in the database
# lvm_libvirt_pool: The logical storage pool (if it exists), as it is
#                   represented in the database

def refresh_pool(task)
  puts "refresh_pool"

  phys_db_pool = task.storage_pool
  if phys_db_pool == nil
    raise "Could not find storage pool"
  end

  conn = storage_find_suitable_host(phys_db_pool.hardware_pool_id)

  begin
    phys_libvirt_pool = LibvirtPool.factory(phys_db_pool)
    phys_libvirt_pool.connect(conn)

    begin
      # OK, the pool is all set.  Add in all of the volumes
      add_volumes_to_db(phys_db_pool, phys_libvirt_pool)

      # OK, now we've scanned the underlying hardware pool and added the
      # volumes.  Next we scan for pre-existing LVM volumes
      logical_xml = conn.discover_storage_pool_sources("logical")

      Document.new(logical_xml).elements.each('sources/source') do |source|
        vgname = source.elements["name"].text

        begin
          source.elements.each("device") do |device|
            byid_device = phys_libvirt_pool.lookup_vol_by_path(device.attributes["path"]).path
          end
        rescue
          # If matching any of the <device> sections in the LVM XML fails
          # against the storage pool, then it is likely that this is a storage
          # pool not associated with the one we connected above.  Go on
          # FIXME: it would be nicer to catch the right exception here, and
          # fail on other exceptions
          puts "One of the logical volumes in #{vgname} is not part of the pool of type #{phys_db_pool[:type]} that we are scanning; ignore the previous error!"
          next
        end

        # if we make it here, then we were able to resolve all of the devices,
        # so we know we need to use a new pool
        lvm_db_pool = LvmStoragePool.find(:first, :conditions =>
                                          [ "vg_name = ?", vgname ])
        if lvm_db_pool == nil
          lvm_db_pool = LvmStoragePool.new
          lvm_db_pool[:type] = "LvmStoragePool"
          # set the LVM pool to the same hardware pool as the underlying storage
          lvm_db_pool.hardware_pool_id = phys_db_pool.hardware_pool_id
          lvm_db_pool.vg_name = vgname
          lvm_db_pool.save
        end

        source.elements.each("device") do |device|
          byid_device = phys_libvirt_pool.lookup_vol_by_path(device.attributes["path"]).path
          physical_vol = StorageVolume.find(:first, :conditions =>
                                            [ "path = ?",  byid_device])
          if physical_vol == nil
            # Hm. We didn't find the device in the storage volumes already.
            # something went wrong internally, and we have to bail
            raise "Storage internal physical volume error"
          end

          # OK, put the right lvm_pool_id in place
          physical_vol.lvm_pool_id = lvm_db_pool.id
          physical_vol.save
        end

        lvm_libvirt_pool = LibvirtPool.factory(lvm_db_pool)
        lvm_libvirt_pool.connect(conn)

        begin
          add_volumes_to_db(lvm_db_pool, lvm_libvirt_pool, "0744", "0744", "0744")
        ensure
          lvm_libvirt_pool.shutdown
        end
      end
    ensure
      phys_libvirt_pool.shutdown
    end
  ensure
    conn.close
  end
end

def create_volume(task)
  puts "create_volume"

  lvm_db_volume = task.storage_volume
  if lvm_db_volume == nil
    raise "Could not find storage volume to create"
  end
  if lvm_db_volume[:type] != "LvmStorageVolume"
    raise "The volume to create must be of type LvmStorageVolume, not type #{lvm_db_volume[:type]}"
  end

  lvm_db_pool = lvm_db_volume.storage_pool
  if lvm_db_pool == nil
    raise "Could not find storage pool"
  end
  if lvm_db_pool[:type] != "LvmStoragePool"
    raise "The pool for the volume must be of type LvmStoragePool, not type #{lvm_db_pool[:type]}"
  end

  conn = storage_find_suitable_host(lvm_db_pool.hardware_pool_id)

  begin
    phys_libvirt_pool = get_libvirt_pool_from_volume(lvm_db_volume)
    phys_libvirt_pool.connect(conn)

    begin
      lvm_libvirt_pool = LibvirtPool.factory(lvm_db_pool)
      lvm_libvirt_pool.connect(conn)

      begin
        vol_xml = build_libvirt_vol_xml(lvm_db_volume.lv_name,
                                        lvm_db_volume.size,
                                        lvm_db_volume.lv_owner_perms,
                                        lvm_db_volume.lv_group_perms,
                                        lvm_db_volume.lv_mode_perms)

        lvm_libvirt_pool.create_vol_xml(vol_xml.to_s)
      ensure
        lvm_libvirt_pool.shutdown
      end
    ensure
      phys_libvirt_pool.shutdown
    end
  ensure
    conn.close
  end
end

def delete_volume(task)
  puts "delete_volume"

  lvm_db_volume = task.storage_volume
  if lvm_db_volume == nil
    raise "Could not find storage volume to delete"
  end
  if lvm_db_volume[:type] != "LvmStorageVolume"
    raise "The volume to delete must be of type LvmStorageVolume, not type #{lvm_db_volume[:type]}"
  end

  lvm_db_pool = lvm_db_volume.storage_pool
  if lvm_db_pool == nil
    raise "Could not find storage pool"
  end
  if lvm_db_pool[:type] != "LvmStoragePool"
    raise "The pool for the volume must be of type LvmStoragePool, not type #{lvm_db_pool[:type]}"
  end

  conn = storage_find_suitable_host(lvm_db_pool.hardware_pool_id)

  begin
    phys_libvirt_pool = get_libvirt_pool_from_volume(lvm_db_volume)
    phys_libvirt_pool.connect(conn)

    begin
      lvm_libvirt_pool = LibvirtPool.factory(lvm_db_pool)
      lvm_libvirt_pool.connect(conn)

      begin
        libvirt_volume = lvm_libvirt_pool.lookup_vol_by_name(lvm_db_volume.lv_name)
        # FIXME: we actually probably want to zero out the whole volume here, so
        # we aren't potentially leaking data from one user to another.  There
        # are two problems, though:
        # 1)  I'm not sure how I would go about zero'ing the data on a remote
        # machine, since there is no "libvirt_write_data" call
        # 2)  This could potentially take quite a while, so we want to spawn
        # off another thread to do it
        libvirt_volume.delete

        # FIXME: we really should be using lvm_db_volume.destroy here, but when
        # I tried it I ran into some "Stale db reference" errors with
        # ActiveRecord.  sseago thinks this could be indicative of a deeper
        # error, so we need to investigate it more
        LvmStorageVolume.delete(lvm_db_volume.id)
      ensure
        lvm_libvirt_pool.shutdown
      end
    ensure
      phys_libvirt_pool.shutdown
    end
  ensure
    conn.close
  end
end
