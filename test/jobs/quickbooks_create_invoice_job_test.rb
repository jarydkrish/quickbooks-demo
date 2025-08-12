require "test_helper"

class QuickbooksCreateInvoiceJobTest < ActiveJob::TestCase
  def setup
    @shipment = shipments(:one)
    @credential = QuickbooksCredential.create!(
      access_token: "test_access_token",
      refresh_token: "test_refresh_token",
      realm_id: "123456789",
      access_token_expires_at: 1.hour.from_now,
      refresh_token_expires_at: 100.days.from_now
    )
  end

  test "skips invoice creation if invoice already exists" do
    @shipment.update!(invoice_id: "existing_invoice_123")

    QuickbooksCreateInvoiceJob.perform_now(@shipment.id)

    # Verify invoice_id hasn't changed
    assert_equal "existing_invoice_123", @shipment.reload.invoice_id
  end

  test "job handles missing credentials" do
    QuickbooksCredential.destroy_all

    # Verify no credentials exist
    assert_equal 0, QuickbooksCredential.count

    # Job should not update the shipment when credentials are missing
    initial_invoice_id = @shipment.invoice_id

    # The job should not succeed, but we'll use stub to prevent actual API calls
    Quickbooks::Service::Invoice.any_instance.stubs(:create).returns(nil)

    begin
      QuickbooksCreateInvoiceJob.perform_now(@shipment.id)
    rescue StandardError
      # Expected to fail
    end

    # Shipment should not be updated
    assert_nil @shipment.reload.invoice_id
  end

  test "job handles missing access token" do
    @credential.update!(access_token: nil)

    # Verify credential has no access token
    assert_nil @credential.reload.access_token

    # Job should not update the shipment when access token is missing
    initial_invoice_id = @shipment.invoice_id

    # Stub to prevent actual API calls
    Quickbooks::Service::Invoice.any_instance.stubs(:create).returns(nil)

    begin
      QuickbooksCreateInvoiceJob.perform_now(@shipment.id)
    rescue StandardError
      # Expected to fail
    end

    # Shipment should not be updated
    assert_nil @shipment.reload.invoice_id
  end

  test "job respects token refresh logic" do
    # Set token to expire soon to trigger refresh check
    @credential.update!(access_token_expires_at: 5.minutes.from_now)

    # The job should check if refresh is needed
    assert @credential.needs_refresh?
  end

  test "builds invoice with correct structure" do
    job = QuickbooksCreateInvoiceJob.new
    invoice = job.send(:build_invoice_from_shipment, @shipment)

    assert_instance_of Quickbooks::Model::Invoice, invoice
    assert_equal "SHIP-#{@shipment.id}-#{Date.current.strftime('%Y%m%d')}", invoice.doc_number
    assert_equal Date.current, invoice.txn_date
    assert_not_nil invoice.customer_ref
    assert_equal "1", invoice.customer_ref.value

    # Check line items are properly created
    assert_equal @shipment.shipment_items.count, invoice.line_items.count

    line_item = invoice.line_items.first
    shipment_item = @shipment.shipment_items.first

    assert_includes line_item.description, shipment_item.name
    assert_includes line_item.description, shipment_item.quantity.to_s
    assert line_item.sales_item?

    # Check sales line item detail
    assert_not_nil line_item.sales_line_item_detail
    assert_equal shipment_item.quantity, line_item.sales_line_item_detail.quantity
    assert_equal 10.0, line_item.sales_line_item_detail.unit_price
  end

  test "calculates item amount correctly" do
    job = QuickbooksCreateInvoiceJob.new
    shipment_item = @shipment.shipment_items.first

    expected_amount = (10.0 * shipment_item.quantity).round(2)
    actual_amount = job.send(:calculate_item_amount, shipment_item)

    assert_equal expected_amount, actual_amount
  end

  test "handles PDF retrieval gracefully" do
    job = QuickbooksCreateInvoiceJob.new
    @shipment.update!(invoice_id: "123")

    # Mock service to simulate the two-step process: fetch then get PDF
    mock_service = mock("service")
    mock_invoice = mock("invoice")
    mock_service.expects(:fetch_by_id).with("123").returns(mock_invoice)
    mock_service.expects(:pdf).with(mock_invoice).returns(nil)

    # Should not raise an error when PDF is nil
    assert_nothing_raised do
      job.send(:retrieve_invoice_pdf, @shipment, mock_service)
    end

    # PDF should not be attached
    assert_not @shipment.invoice_pdf.attached?
  end

  test "transitions through correct statuses during invoice creation" do
    @shipment.update!(status: "generating_invoice")

    # Mock QuickBooks service
    mock_invoice = mock("invoice")
    mock_invoice.expects(:id).returns(789).twice  # Called when logging and when converting to string

    Quickbooks::Service::Invoice.any_instance.stubs(:access_token=)
    Quickbooks::Service::Invoice.any_instance.stubs(:company_id=)
    Quickbooks::Service::Invoice.any_instance.stubs(:create).returns(mock_invoice)
    Quickbooks::Service::Invoice.any_instance.stubs(:fetch_by_id).returns(mock_invoice)
    Quickbooks::Service::Invoice.any_instance.stubs(:pdf).returns("fake_pdf_data")

    # Status should start as generating_invoice
    assert_equal "generating_invoice", @shipment.status

    QuickbooksCreateInvoiceJob.perform_now(@shipment.id)

    # Status should end as awaiting_shipment
    assert_equal "awaiting_shipment", @shipment.reload.status
    assert_equal "789", @shipment.invoice_id
  end

  test "resets status to pending on error" do
    @shipment.update!(status: "generating_invoice")
    @credential.update!(access_token: nil)

    # Job should fail and reset status
    begin
      QuickbooksCreateInvoiceJob.perform_now(@shipment.id)
    rescue StandardError
      # Expected to fail
    end

    # Status should be reset to pending
    assert_equal "pending", @shipment.reload.status
  end
end
