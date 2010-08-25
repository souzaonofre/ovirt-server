class AddVirtioToVmAndNic < ActiveRecord::Migration
  def self.up
    add_column :vms, :virtio, :boolean, :default => false
    add_column :nics, :virtio, :boolean, :default => false
  end

  def self.down
    remove_column :vms, :virtio
    remove_column :nics, :virtio
  end
end
