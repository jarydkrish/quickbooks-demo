class QuickbooksCredential < ApplicationRecord
  # OAuth2 access token for QuickBooks API
  # We want to avoid caching this, as we may refresh it
  def oauth_access_token
    OAuth2::AccessToken.new(client, access_token, refresh_token: refresh_token)
  end

  # Refreshing the token
  def refresh_token!
    raise "No refresh token available" if refresh_token.blank?

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

    Rails.logger.info "Token refreshed successfully for credential ID: #{id}"
    self
  rescue OAuth2::Error => e
    Rails.logger.error "OAuth2 error refreshing token for credential ID: #{id} - #{e.message}"
    raise e
  rescue => e
    Rails.logger.error "Unexpected error refreshing token for credential ID: #{id} - #{e.message}"
    raise e
  end

  # Check if token needs refresh (expires within 10 minutes)
  def needs_refresh?
    return false if access_token.blank?
    return false if access_token_expires_at.nil?

    # Refresh if token expires within the next 10 minutes
    access_token_expires_at <= 10.minutes.from_now
  end

  # Check if refresh token is still valid
  def refresh_token_valid?
    refresh_token.present? &&
    (refresh_token_expires_at.nil? || refresh_token_expires_at > Time.current)
  end

  # Get the time when this token should be refreshed (10 minutes before expiry)
  def refresh_at
    return nil if access_token.blank? || access_token_expires_at.nil?

    refresh_time = access_token_expires_at - 10.minutes
    # Don't schedule in the past
    [ refresh_time, 1.minute.from_now ].max
  end

  # Get the next time we should check for any tokens to refresh
  def self.next_refresh_check_at
    # Find credentials with valid refresh tokens
    valid_credentials = where.not(access_token: nil)
                            .where.not(access_token_expires_at: nil)
                            .where(
                              refresh_token_expires_at: nil
                            ).or(
                              where("refresh_token_expires_at > ?", Time.current)
                            )

    # Get the earliest refresh time needed
    earliest_expiry = valid_credentials.minimum(:access_token_expires_at)

    if earliest_expiry
      # Schedule 10 minutes before the earliest expiry
      refresh_time = earliest_expiry - 10.minutes
      # Don't schedule in the past, minimum 1 minute from now
      [ refresh_time, 1.minute.from_now ].max
    else
      # Default fallback: check again in 1 hour
      1.hour.from_now
    end
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
