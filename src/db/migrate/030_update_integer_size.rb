class UpdateIntegerSize < ActiveRecord::Migration
  def self.up
    #Since we store mem, storage, etc in KB, we need an 8 byte int.
    #Change all tables with this type of data to support larger size

    change_column :hosts, :memory, :integer, :limit => 8
    change_column :storage_volumes, :size, :integer, :limit => 8
    change_column :quotas, :total_vmemory, :integer, :limit => 8
    change_column :quotas, :total_storage, :integer, :limit => 8
    change_column :vms, :memory_allocated, :integer, :limit => 8
    change_column :vms, :memory_used, :integer, :limit => 8
  end

  def self.down
    change_column :hosts, :memory, :integer, :limit => 4
    change_column :storage_volumes, :size, :integer, :limit => 4
    change_column :quotas, :total_vmemory, :integer, :limit => 4
    change_column :quotas, :total_storage, :integer, :limit => 4
    change_column :vms, :memory_allocated, :integer, :limit => 4
    change_column :vms, :memory_used, :integer, :limit => 4
  end
end
