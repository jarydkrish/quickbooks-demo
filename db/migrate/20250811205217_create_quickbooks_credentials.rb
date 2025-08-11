class CreateQuickbooksCredentials < ActiveRecord::Migration[8.0]
  def change
    create_table :quickbooks_credentials do |t|
      t.string :realm_id, null: true
      t.string :access_token, null: true
      t.datetime :access_token_expires_at, null: true
      t.string :refresh_token, null: true
      t.datetime :refresh_token_expires_at, null: true
      t.timestamps
    end
  end
end
