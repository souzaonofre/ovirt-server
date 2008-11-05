
class FixUniquenessConstraintsInBondingsNics < ActiveRecord::Migration
  def self.up
    remove_index :bondings_nics, [:bonding_id, :nic_id]
    add_index :bondings_nics, :nic_id, :unique => true
  end

  def self.down
    remove_index :bondings_nics, :nic_id
    add_index :bondings_nics, [:bonding_id, :nic_id], :unique => true
  end
end

