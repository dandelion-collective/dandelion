$VERBOSE = false
require File.expand_path('../config/boot', __dir__)

require 'capybara'
require 'capybara/dsl'
require 'capybara/apparition'
require 'factory_bot'
require 'minitest/autorun'
require 'minitest/rg'
require 'rack_session_access/capybara'

Capybara.app = Padrino.application
Capybara.server_port = ENV['PORT']
Capybara.save_path = 'capybara'
Capybara.default_max_wait_time = 10
FileUtils.rm_rf("#{Capybara.save_path}/.") unless ENV['CI']

Capybara.register_driver :apparition do |app|
  options = {}
  options[:js_errors] = false
  options[:browser_logger] = nil
  Capybara::Apparition::Driver.new(app, options)
end
Capybara.javascript_driver = :apparition
Capybara.default_driver = :apparition

module ActiveSupport
  class TestCase
    def login_as(account)
      page.set_rack_session(account_id: account.id.to_s)
      visit '/'
    end
  end
end
