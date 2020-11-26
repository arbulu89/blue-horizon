# frozen_string_literal: true

class DashboardsController < ApplicationController
  def show
    @request_id = params[:id].to_sym
    @outputs = Terraform.new.outputs
    # Redirect to a known dashboard if the request id is not found
    return if helpers.dashboard(@request_id, @outputs).present?

    redirect_to dashboard_path(helpers.first_item)
  end
end
