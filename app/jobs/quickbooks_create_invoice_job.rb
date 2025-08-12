class QuickbooksCreateInvoiceJob < ApplicationJob
  queue_as :default

  retry_on StandardError, wait: 5.minutes, attempts: 3

  def perform(shipment_id)
    shipment = Shipment.find(shipment_id)

    # Skip if invoice already exists
    if shipment.has_invoice?
      Rails.logger.info "Invoice already exists for shipment #{shipment.id}"
      return
    end

    # Get QuickBooks credentials
    credential = QuickbooksCredential.first
    unless credential&.access_token.present?
      Rails.logger.error "No QuickBooks credentials available"
      raise StandardError.new("QuickBooks not connected")
    end

    # Refresh token if needed
    credential.refresh_token! if credential.needs_refresh?

    # Create QuickBooks service
    service = Quickbooks::Service::Invoice.new
    service.access_token = credential.oauth_access_token
    service.company_id = credential.realm_id

    # Build invoice
    invoice = build_invoice_from_shipment(shipment)

    # Create invoice in QuickBooks
    created_invoice = service.create(invoice)

    # Update shipment with invoice ID
    shipment.update!(invoice_id: created_invoice.id.to_s)

    Rails.logger.info "Created QuickBooks invoice #{created_invoice.id} for shipment #{shipment.id}"

    # Update status to downloading packslip before getting PDF
    shipment.status_downloading_packslip!
    Rails.logger.info "Downloading PDF for shipment #{shipment.id}"

    # Get invoice PDF
    retrieve_invoice_pdf(shipment, service)

    # Update to awaiting shipment after successful invoice creation
    shipment.status_awaiting_shipment!
    Rails.logger.info "Shipment #{shipment.id} ready for shipping"
  rescue OAuth2::Error => e
    Rails.logger.error "OAuth2 error creating invoice for shipment #{shipment_id}: #{e.message}"
    # Reset status to pending on error
    shipment.status_pending! if shipment
    raise e
  rescue => e
    Rails.logger.error "Error creating invoice for shipment #{shipment_id}: #{e.message}"
    # Reset status to pending on error
    shipment.status_pending! if shipment
    raise e
  end

  private

  def build_invoice_from_shipment(shipment)
    # Create QuickBooks invoice object
    invoice = Quickbooks::Model::Invoice.new
    invoice.doc_number = "SHIP-#{shipment.id}-#{Date.current.strftime('%Y%m%d')}"
    invoice.txn_date = Date.current

    # Set customer reference (requires a valid customer ID from your QB company)
    # For demo purposes, using customer ID "1" - you'll need to use actual customer IDs
    customer_ref = Quickbooks::Model::BaseReference.new
    customer_ref.value = "1" # This should be a real customer ID from your QB company
    invoice.customer_ref = customer_ref

    # Create line items from shipment items
    invoice.line_items = []

    shipment.shipment_items.each do |item|
      line_item = Quickbooks::Model::InvoiceLineItem.new
      line_item.description = "#{item.name} (Qty: #{item.quantity})"
      line_item.amount = calculate_item_amount(item)

      # Use the sales_item! method as shown in the documentation
      line_item.sales_item! do |line|
        # Set item reference - this should be a real item ID from your QB company
        item_ref = Quickbooks::Model::BaseReference.new
        item_ref.value = "1" # This should be a real item ID from your QB company
        line.item_ref = item_ref

        line.quantity = item.quantity
        line.unit_price = 10.0 # Base price per item for demo
      end

      invoice.line_items << line_item
    end

    invoice
  end

  def calculate_item_amount(item)
    # For demo purposes, use a simple calculation
    # In a real app, you'd have actual pricing
    base_price = 10.0 # $10 per item
    (base_price * item.quantity).round(2)
  end

  def retrieve_invoice_pdf(shipment, service)
    return unless shipment.invoice_id.present?

    Rails.logger.info "Retrieving PDF for invoice #{shipment.invoice_id}"

    # Get PDF from QuickBooks
    # First fetch the invoice by ID, then get its PDF
    invoice = service.fetch_by_id(shipment.invoice_id)
    pdf_data = service.pdf(invoice)

    if pdf_data
      # Attach PDF to shipment using ActiveStorage
      shipment.invoice_pdf.attach(
        io: StringIO.new(pdf_data),
        filename: "invoice_#{shipment.invoice_id}.pdf",
        content_type: "application/pdf"
      )

      Rails.logger.info "Attached PDF for invoice #{shipment.invoice_id} to shipment #{shipment.id}"
    else
      Rails.logger.warn "No PDF data received for invoice #{shipment.invoice_id}"
    end

  rescue => e
    Rails.logger.error "Error retrieving PDF for invoice #{shipment.invoice_id}: #{e.message}"
    # Don't re-raise - invoice was created successfully, PDF retrieval is secondary
    raise e
  end
end
