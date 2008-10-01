class CreateHelpSections < ActiveRecord::Migration
  def self.up
    create_table :help_sections do |t|
      t.string :controller, :null => false, :limit => 25
      t.string :action, :null => false, :limit => 25
      t.string :section, :null => false, :limit => 100
    end
  end

  def self.down
    drop_table :help_sections
  end
end
