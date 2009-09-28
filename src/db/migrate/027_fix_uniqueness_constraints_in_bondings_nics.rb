
class FixUniquenessConstraintsInBondingsNics < ActiveRecord::Migration
  def self.up
    # Mysql 5.* forces foreign key to have an index, for performance reason.
    # One cannot remove an index before drop foreign key on it.
    remove_foreign_key :bondings_nics, :name => 'fk_bondings_nics_bonding'
    remove_foreign_key :bondings_nics, :name => 'fk_bondings_nics_nic'

    remove_index :bondings_nics, [:bonding_id, :nic_id]
    add_index :bondings_nics, :nic_id, :unique => true

    # it can be re-added afterwards, without any problem
    add_foreign_key :bondings_nics, :bondings,
                    :name => 'fk_bondings_nics_bonding'
    add_foreign_key :bondings_nics, :nics, :name => 'fk_bondings_nics_nic'
  end

  def self.down
    remove_index :bondings_nics, :nic_id
    add_index :bondings_nics, [:bonding_id, :nic_id], :unique => true
  end
end
