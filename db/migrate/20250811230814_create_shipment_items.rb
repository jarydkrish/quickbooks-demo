class CreateShipmentItems < ActiveRecord::Migration[8.0]
  def change
    create_table :shipment_items do |t|
      t.references :shipment, null: false, foreign_key: true
      t.string :name
      t.integer :quantity

      t.timestamps
    end
  end
end
