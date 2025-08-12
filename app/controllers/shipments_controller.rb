class ShipmentsController < ApplicationController
  before_action :set_shipment, only: %i[show edit update destroy create_invoice]

  def index
    @shipments = Shipment.includes(:shipment_items).order(created_at: :desc)
  end

  def show
  end

  def new
    @shipment = Shipment.new
    @shipment.shipment_items.build
  end

  def edit
    @shipment.shipment_items.build if @shipment.shipment_items.empty?
  end

  def create
    @shipment = Shipment.new(shipment_params)

    if @shipment.save
      redirect_to shipments_path, notice: "Shipment was successfully created.", status: :see_other
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @shipment.update(shipment_params)
      redirect_to @shipment, notice: "Shipment was successfully updated.", status: :see_other
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @shipment.destroy!

    redirect_to shipments_path, notice: "Shipment was successfully destroyed.", status: :see_other
  end

  def create_invoice
    if @shipment.has_invoice?
      redirect_back_or_to @shipment, alert: "Invoice already exists for this shipment."
      return
    end

    # Check if QuickBooks is connected
    unless QuickbooksCredential.first&.access_token.present?
      redirect_back_or_to @shipment, alert: "QuickBooks not connected. Please connect first."
      return
    end

    @shipment.status_generating_invoice!

    # Queue the job to create the invoice
    QuickbooksCreateInvoiceJob.perform_later(@shipment.id)

    redirect_back_or_to @shipment, notice: "Invoice creation started. PDF will be available shortly."
  end

  private

  def set_shipment
    @shipment = Shipment.find(params[:id])
  end

  def shipment_params
    params.require(:shipment).permit(:description, :status, :shipped_at,
      shipment_items_attributes: [ :id, :name, :quantity, :_destroy ])
  end
end
