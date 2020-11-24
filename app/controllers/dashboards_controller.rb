# frozen_string_literal: true

class DashboardsController < ApplicationController
  def show
    @id = params[:id].to_i
  end
end
