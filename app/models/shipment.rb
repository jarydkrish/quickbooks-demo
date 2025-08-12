class Shipment < ApplicationRecord
  has_many :shipment_items, dependent: :destroy
  accepts_nested_attributes_for :shipment_items, allow_destroy: true, reject_if: :all_blank

  validates :description, presence: true

  broadcasts_to ->(shipment) { "shipments" }, inserts_by: :prepend, target: "shipments"

  enum :status, {
    pending: "pending",
    processing: "processing",
    shipped: "shipped",
    delivered: "delivered",
    cancelled: "cancelled"
  }, default: "pending", prefix: true
end
