class Shipment < ApplicationRecord
  has_many :shipment_items, dependent: :destroy
  accepts_nested_attributes_for :shipment_items, allow_destroy: true, reject_if: :all_blank

  has_one_attached :invoice_pdf

  validates :description, presence: true

  broadcasts_to ->(shipment) { "shipments" }, inserts_by: :prepend, target: "shipments"

  enum :status, {
    pending: "pending",
    generating_invoice: "generating_invoice",
    downloading_packslip: "downloading_packslip",
    awaiting_shipment: "awaiting_shipment",
    shipped: "shipped",
    delivered: "delivered",
    cancelled: "cancelled"
  }, default: "pending", prefix: true

  # Check if this shipment has a QuickBooks invoice
  def has_invoice?
    invoice_id.present?
  end

  # Check if invoice PDF is attached
  def has_invoice_pdf?
    invoice_pdf.attached?
  end
end
