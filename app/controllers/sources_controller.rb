# frozen_string_literal: true

require 'json'

class SourcesController < ApplicationController
  include Exportable
  before_action :set_sources, only: [:index, :show, :new, :edit]
  before_action :set_source, only: [:show, :edit, :update, :destroy]

  # GET /sources
  def index; end

  # GET /sources/1
  def show; end

  # GET /sources/new
  def new
    @source = Source.new
  end

  # GET /sources/1/edit
  def edit; end

  # POST /sources
  def create
    unless params[:source]['filename'].empty?
      @source = Source.new(source_params)

      return terra_validate if @source.save

      set_sources
      return render :new
    end

    return redirect_to(new_source_path,
      flash: { error: 'Source filename can not be empty.' }
    )
  end

  # PATCH/PUT /sources/1
  def update
    if @source.update(source_params)
      terra_validate
    else
      set_sources
      render :new
    end
  end

  # DELETE /sources/1
  def destroy
    @source.destroy
    redirect_to(sources_path, notice: 'Source was successfully destroyed.')
  end

  private

  def set_sources
    @sources = Source.all.order(:filename)
  end

  def set_source
    @source = Source.find(params[:id])
  end

  def source_params
    params.require(:source).permit(:filename, :content)
  end

  def terra_validate
    # Source.all.each(&:export)
    @source.export
    terra = Terraform.new
    output = terra.validate(true)

    if output
      flash = { error: output }
    else
      message = 'Source was successfully '
      message += params[:action] == 'create' ? 'created.' : 'updated.'
      flash = { notice: message }
    end
    return redirect_to edit_source_path(@source), flash: flash if
      params[:action] == 'create'

    redirect_to edit_source_path, flash: flash
  end
end
