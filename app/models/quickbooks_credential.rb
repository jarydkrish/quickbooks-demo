class QuickbooksCredential < ApplicationRecord
  # OAuth2 access token for QuickBooks API
  # We want to avoid caching this, as we may refresh it
  def oauth_access_token
    OAuth2::AccessToken.new(client, access_token, refresh_token: refresh_token)
  end

  # Refreshing the token
  def refresh_token!
    t = oauth_access_token
    refreshed = t.refresh!

    if refreshed.params["x_refresh_token_expires_in"].to_i > 0
      refresh_token_expires_at = Time.now + refreshed.params["x_refresh_token_expires_in"].to_i.seconds
    else
      refresh_token_expires_at = 100.days.from_now
    end

    update!(
      access_token: refreshed.token,
      access_token_expires_at: Time.at(refreshed.expires_at),
      refresh_token: refreshed.refresh_token,
      refresh_token_expires_at: refresh_token_expires_at
    )
  end

  #
  # OAUTH CLIENT
  #

  # OAuth2 client for QuickBooks API
  def self.client
    oauth_params = {
      site: "https://appcenter.intuit.com/connect/oauth2",
      authorize_url: "https://appcenter.intuit.com/connect/oauth2",
      token_url: "https://oauth.platform.intuit.com/oauth2/v1/tokens/bearer"
    }
    @client ||= OAuth2::Client.new(
      ENV["INTUIT_CLIENT_ID"],
      ENV["INTUIT_CLIENT_SECRET"],
      oauth_params,
    )
  end

  def client
    @client ||= self.class.client
  end
end
