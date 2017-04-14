class AddUniqueNameConstraintToUsers < ActiveRecord::Migration
  def up
  	remove_index :users, :name
  	execute "create unique index index_users_on_name on users(lower(name))"
  end
end
