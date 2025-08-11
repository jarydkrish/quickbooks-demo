require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  test "home shows connect CTA when not connected" do
    QuickbooksCredential.delete_all
    old_id, old_secret = ENV["INTUIT_CLIENT_ID"], ENV["INTUIT_CLIENT_SECRET"]
    ENV["INTUIT_CLIENT_ID"] = "test-id"
    ENV["INTUIT_CLIENT_SECRET"] = "test-secret"
    get root_url
    assert_response :success
    assert_select "h2", text: /Connect your QuickBooks account/
    assert_select "a", text: /Connect QuickBooks/
  ensure
    ENV["INTUIT_CLIENT_ID"] = old_id
    ENV["INTUIT_CLIENT_SECRET"] = old_secret
  end

  test "home shows connected state when credential has realm_id" do
    QuickbooksCredential.delete_all
    QuickbooksCredential.create!(realm_id: "123", access_token: "t", refresh_token: "r")
    get root_url
    assert_response :success
    assert_select "h2", text: /You're connected/
    assert_select "a", { text: /Connect QuickBooks/, count: 0 }
  end
end
