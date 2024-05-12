require 'capybara/rspec'
require 'capybara/rails' if defined?(Rails)
require 'selenium-webdriver'

RSpec.configure do |config|
  Capybara.default_driver = :selenium_chrome_headless # For headless testing
  # Capybara.default_driver = :selenium_chrome to see the browser in action

  Capybara.javascript_driver = :selenium_chrome_headless
  # Capybara.javascript_driver = :selenium_chrome for visible browser interaction
end
