require "test_helper"

class ShipmentTest < ActiveSupport::TestCase
  test "should not save shipment without description" do
    shipment = Shipment.new
    assert_not shipment.save, "Saved the shipment without a description"
  end

  test "should save valid shipment" do
    shipment = Shipment.new(description: "Test shipment")
    assert shipment.save
  end

  test "should have pending status by default" do
    shipment = Shipment.new(description: "Test shipment")
    assert_equal "pending", shipment.status
  end

  test "should accept nested attributes for shipment items" do
    shipment = Shipment.new(
      description: "Test shipment",
      shipment_items_attributes: [
        { name: "Item 1", quantity: 5 },
        { name: "Item 2", quantity: 3 }
      ]
    )
    assert shipment.save
    assert_equal 2, shipment.shipment_items.count
  end

  test "should destroy associated shipment items when destroyed" do
    shipment = Shipment.create!(description: "Test shipment")
    shipment.shipment_items.create!(name: "Item 1", quantity: 5)

    assert_difference "ShipmentItem.count", -1 do
      shipment.destroy
    end
  end

  test "has_invoice? returns true when invoice_id is present" do
    shipment = Shipment.new(description: "Test", invoice_id: "123")
    assert shipment.has_invoice?
  end

  test "has_invoice? returns false when invoice_id is blank" do
    shipment = Shipment.new(description: "Test")
    assert_not shipment.has_invoice?
  end

  test "has_invoice_pdf? returns true when PDF is attached" do
    shipment = Shipment.create!(description: "Test")
    shipment.invoice_pdf.attach(
      io: StringIO.new("fake pdf content"),
      filename: "test.pdf",
      content_type: "application/pdf"
    )
    assert shipment.has_invoice_pdf?
  end

  test "has_invoice_pdf? returns false when no PDF is attached" do
    shipment = Shipment.create!(description: "Test")
    assert_not shipment.has_invoice_pdf?
  end
end
