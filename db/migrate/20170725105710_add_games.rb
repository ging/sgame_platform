class AddGames < ActiveRecord::Migration[4.2]
  def change
    create_table :games do |t|
      t.integer :game_template_id
      t.integer :owner_id
      t.string :title
      t.text :description
      t.text :thumbnail_url
      t.string :language
      t.boolean  :draft, :default => false
      t.datetime :scorm2004_timestamp
      t.datetime :scorm12_timestamp
      t.boolean  :certified, :default => false
      t.timestamps
    end

    add_attachment :games, :thumbnail
  end
end