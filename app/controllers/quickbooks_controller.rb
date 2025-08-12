class QuickbooksController < ApplicationController
  def authenticate
    redirect_uri = quickbooks_oauth_callback_url
    quickbooks_credentials = QuickbooksCredential.first_or_create!
    grant_url = quickbooks_credentials.client.auth_code.authorize_url(
      redirect_uri: redirect_uri,
      response_type: "code",
      state: quickbooks_credentials.to_gid_param,
      scope: "com.intuit.quickbooks.accounting"
    )
    # We want to redirect to another host
    redirect_to grant_url, allow_other_host: true
  end

  def oauth_callback
    if params[:state].present?
      # Find our quickbooks_credentials using GlobalID
      quickbooks_credentials = GlobalID::Locator.locate(params[:state])
      redirect_uri = quickbooks_oauth_callback_url
      if resp = quickbooks_credentials.client.auth_code.get_token(params[:code], redirect_uri: redirect_uri)
        # Let's update our token with the new values
        quickbooks_credentials.update(
          access_token: resp.token,
          refresh_token: resp.refresh_token,
          realm_id: params[:realmId],
          access_token_expires_at: resp.expires_at ? Time.at(resp.expires_at) : 1.hour.from_now,
          refresh_token_expires_at: resp.params["x_refresh_token_expires_in"] ?
            Time.now + resp.params["x_refresh_token_expires_in"].to_i.seconds :
            100.days.from_now
        )

        # Start the token refresh job cycle using dynamic scheduling
        next_check_at = QuickbooksCredential.next_refresh_check_at
        wait_time = [ (next_check_at - Time.current), 1.minute ].max

        QuickbooksTokenRefreshJob.set(wait: wait_time).perform_later
        Rails.logger.info "QuickBooks token refresh job scheduled for #{next_check_at.strftime('%Y-%m-%d %H:%M:%S')}"

        # We want to return now, as we are done connecting
        return redirect_to root_path, notice: "QuickBooks account connected successfully."
      end
    end
    redirect_to root_path, alert: "Failed to connect QuickBooks account."
  end
end
