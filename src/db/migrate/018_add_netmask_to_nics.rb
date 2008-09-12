class AddNetmaskToNics < ActiveRecord::Migration
  def self.up
    add_column :nics, :netmask,   :string, :limit => 16
    add_column :nics, :broadcast, :string, :limit => 16
  end

  def self.down
    remove_column :nics, :netmask
    remove_column :nics, :broadcast
  end
end
