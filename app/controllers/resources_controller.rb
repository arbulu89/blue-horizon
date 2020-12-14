# frozen_string_literal: true

class ResourcesController < ApplicationController
  def index
    @outputs = Terraform.new.outputs
    @content = t('resources_content') % @outputs
  end
end
