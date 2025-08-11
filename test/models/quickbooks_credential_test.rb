require "test_helper"

class QuickbooksCredentialTest < ActiveSupport::TestCase
  test "refresh_token! updates tokens" do
    cred = QuickbooksCredential.create!(access_token: "old", refresh_token: "oldr")
    stub_request(:post, "https://oauth.platform.intuit.com/oauth2/v1/tokens/bearer").to_return(
      status: 200,
      headers: { "Content-Type" => "application/json" },
      body: {
        access_token: "new-access",
        refresh_token: "new-refresh",
        expires_in: 3600,
        x_refresh_token_expires_in: 200000
      }.to_json
    )

    cred.refresh_token!
    cred.reload
    assert_equal "new-access", cred.access_token
    assert_equal "new-refresh", cred.refresh_token
    assert cred.access_token_expires_at.present?
    assert cred.refresh_token_expires_at.present?
  end
end
