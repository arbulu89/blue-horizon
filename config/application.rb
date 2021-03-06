# frozen_string_literal: true

require_relative 'boot'

require 'rails'
# Pick the frameworks you want:
require 'active_model/railtie'
require 'active_job/railtie'
require 'active_record/railtie'
require 'action_controller/railtie'
# require "action_mailer/railtie"
require 'action_view/railtie'
# require "action_cable/engine"
require 'sprockets/railtie'
require 'rails/test_unit/railtie'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module BlueHorizon
  # Executes all railties and engines initializers.
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 5.1

    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    begin
      # SQLite databases have used 't' and 'f' to serialize boolean values
      config.active_record.sqlite3.represent_boolean_as_integer = true
    rescue NoMethodError
      # This option is not available on Rails 5.1
    end

    # Let sprockets handle fonts in the asset pipeline
    config.assets.paths << Rails.root.join('app', 'assets', 'fonts')
  end
end
