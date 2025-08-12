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
end
