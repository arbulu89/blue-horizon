# frozen_string_literal: true

# Constrains to look for root request
class RootConstraint
  def initialize; end

  def matches?(_request)
    KeyValue.get(:deployment_finished)
  rescue ActiveRecord::RecordNotFound
    false
  end
end
