require "test_helper"

class QuickbooksControllerTest < ActionDispatch::IntegrationTest
  test "authenticate redirects to Intuit authorize" do
    QuickbooksCredential.delete_all
    get quickbooks_authenticate_url
    assert_response :redirect
    assert_match %r{https://appcenter.intuit.com/connect/oauth2\?}, response.headers["Location"]
  end

  test "oauth_callback success updates credentials and redirects home" do
  QuickbooksCredential.delete_all
  cred = QuickbooksCredential.create!
    # Stub token exchange
    token_url = "https://oauth.platform.intuit.com/oauth2/v1/tokens/bearer"
    stub_request(:post, token_url).to_return(
      status: 200,
      headers: { "Content-Type" => "application/json" },
      body: {
        access_token: "new-access",
        refresh_token: "new-refresh",
        expires_in: 3600,
        x_refresh_token_expires_in: 200000
      }.to_json
    )

    state = cred.to_gid_param
    get quickbooks_oauth_callback_url, params: { state: state, code: "abc", realmId: "999" }
    assert_redirected_to root_path
    follow_redirect!
    assert_response :success
    cred.reload
    assert_equal "new-access", cred.access_token
    assert_equal "new-refresh", cred.refresh_token
    assert_equal "999", cred.realm_id
  end

  test "oauth_callback failure redirects with alert" do
    get quickbooks_oauth_callback_url
    assert_redirected_to root_path
  end
end
