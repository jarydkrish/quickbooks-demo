class AddInvoiceIdToShipments < ActiveRecord::Migration[8.0]
  def change
    add_column :shipments, :invoice_id, :string
  end
end
