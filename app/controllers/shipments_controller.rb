class ShipmentsController < ApplicationController
  before_action :set_shipment, only: %i[show edit update destroy]

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

  private

  def set_shipment
    @shipment = Shipment.find(params[:id])
  end

  def shipment_params
    params.require(:shipment).permit(:description, :status, :shipped_at,
      shipment_items_attributes: [ :id, :name, :quantity, :_destroy ])
  end
end
