class CreateShipments < ActiveRecord::Migration[8.0]
  def change
    create_table :shipments do |t|
      t.text :description
      t.string :status
      t.datetime :shipped_at

      t.timestamps
    end
  end
end
