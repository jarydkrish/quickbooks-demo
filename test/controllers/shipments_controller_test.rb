require "test_helper"

class ShipmentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @shipment = shipments(:one)
  end

  test "should get index" do
    get shipments_url
    assert_response :success
  end

  test "should get show" do
    get shipment_url(@shipment)
    assert_response :success
  end

  test "should get new" do
    get new_shipment_url
    assert_response :success
  end

  test "should get edit" do
    get edit_shipment_url(@shipment)
    assert_response :success
  end

  test "should create shipment" do
    assert_difference("Shipment.count") do
      post shipments_url, params: {
        shipment: {
          description: "Test shipment",
          status: "pending",
          shipment_items_attributes: {
            "0" => { name: "Test item", quantity: 1 }
          }
        }
      }
    end

    assert_redirected_to shipments_url
  end

  test "should update shipment" do
    patch shipment_url(@shipment), params: {
      shipment: {
        description: "Updated description"
      }
    }
    assert_redirected_to shipment_url(@shipment)
  end

  test "should destroy shipment" do
    assert_difference("Shipment.count", -1) do
      delete shipment_url(@shipment)
    end

    assert_redirected_to shipments_url
  end

  test "should create invoice when QuickBooks is connected" do
    # Create QuickBooks credential
    QuickbooksCredential.create!(
      access_token: "test_token",
      refresh_token: "test_refresh",
      realm_id: "123",
      access_token_expires_at: 1.hour.from_now,
      refresh_token_expires_at: 100.days.from_now
    )

    assert_enqueued_jobs 1, only: QuickbooksCreateInvoiceJob do
      post create_invoice_shipment_path(@shipment)
    end

    assert_redirected_to shipment_path(@shipment)
    assert_match /Invoice creation started/, flash[:notice]
  end

  test "should not create invoice if already exists" do
    @shipment.update!(invoice_id: "existing_123")

    assert_enqueued_jobs 0, only: QuickbooksCreateInvoiceJob do
      post create_invoice_shipment_path(@shipment)
    end

    assert_redirected_to shipment_path(@shipment)
    assert_match /Invoice already exists/, flash[:alert]
  end

  test "should not create invoice when QuickBooks not connected" do
    QuickbooksCredential.destroy_all

    assert_enqueued_jobs 0, only: QuickbooksCreateInvoiceJob do
      post create_invoice_shipment_path(@shipment)
    end

    assert_redirected_to shipment_path(@shipment)
    assert_match /QuickBooks not connected/, flash[:alert]
  end
end
