class ShipmentItem < ApplicationRecord
  belongs_to :shipment

  validates :name, presence: true
  validates :quantity, presence: true, numericality: { greater_than: 0 }
end
