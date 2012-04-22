class AddFavToPost < ActiveRecord::Migration
  def change
    add_column :posts, :fav, :boolean, :default => 0
  end
end
