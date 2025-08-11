ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "webmock/minitest"
require "vcr"

VCR.configure do |c|
  c.cassette_library_dir = File.expand_path("vcr_cassettes", __dir__)
  c.hook_into :webmock
  c.ignore_localhost = true
  # Don't record by default; rely on WebMock stubs unless explicitly enabled
  c.default_cassette_options = { record: :none }
  # Filter sensitive tokens & client credentials
  c.filter_sensitive_data("<INTUIT_CLIENT_ID>") { ENV["INTUIT_CLIENT_ID"] }
  c.filter_sensitive_data("<INTUIT_CLIENT_SECRET>") { ENV["INTUIT_CLIENT_SECRET"] }
  c.filter_sensitive_data("<ACCESS_TOKEN>") { QuickbooksCredential.first&.access_token }
  c.filter_sensitive_data("<REFRESH_TOKEN>") { QuickbooksCredential.first&.refresh_token }
end

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end

# Disable all external HTTP connections by default in test
WebMock.disable_net_connect!(allow_localhost: true)
