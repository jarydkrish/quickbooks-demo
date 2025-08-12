require "test_helper"

class ShipmentItemTest < ActiveSupport::TestCase
  setup do
    @shipment = Shipment.create!(description: "Test shipment")
  end

  test "should not save shipment item without name" do
    item = @shipment.shipment_items.build(quantity: 5)
    assert_not item.save
  end

  test "should not save shipment item without quantity" do
    item = @shipment.shipment_items.build(name: "Test Item")
    assert_not item.save
  end

  test "should not save shipment item with zero quantity" do
    item = @shipment.shipment_items.build(name: "Test Item", quantity: 0)
    assert_not item.save
  end

  test "should not save shipment item with negative quantity" do
    item = @shipment.shipment_items.build(name: "Test Item", quantity: -1)
    assert_not item.save
  end

  test "should save valid shipment item" do
    item = @shipment.shipment_items.build(name: "Test Item", quantity: 5)
    assert item.save
  end

  test "belongs to shipment" do
    item = ShipmentItem.new(name: "Test Item", quantity: 5)
    assert_not item.save, "Saved shipment item without a shipment"
  end
end
