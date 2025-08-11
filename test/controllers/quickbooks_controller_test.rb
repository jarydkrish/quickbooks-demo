require "test_helper"

class QuickbooksControllerTest < ActionDispatch::IntegrationTest
  test "should get oauth_callback" do
    get quickbooks_oauth_callback_url
    assert_response :success
  end
end
