class QuickbooksTokenRefreshJob < ApplicationJob
  queue_as :default

  retry_on StandardError, wait: 5.minutes, attempts: 3

  def perform
    Rails.logger.info "Starting QuickBooks token refresh job"

    # Find credentials that need refreshing and have valid refresh tokens
    credentials_to_refresh = QuickbooksCredential.where.not(access_token: nil)
      .select(&:needs_refresh?)
      .select(&:refresh_token_valid?)

    if credentials_to_refresh.empty?
      Rails.logger.info "No QuickBooks tokens need refreshing at this time"
      schedule_next_run
      return
    end

    Rails.logger.info "Found #{credentials_to_refresh.count} token(s) to refresh"

    success_count = 0
    failure_count = 0

    credentials_to_refresh.each do |credential|
      begin
        expires_in = credential.access_token_expires_at - Time.current
        Rails.logger.info "Refreshing token for credential ID: #{credential.id} (expires in #{expires_in.to_i} seconds)"
        credential.refresh_token!
        success_count += 1
      rescue => e
        Rails.logger.error "Failed to refresh token for credential ID: #{credential.id} - #{e.message}"
        failure_count += 1
        # Don't re-raise the error here so we can continue with other credentials
      end
    end

    Rails.logger.info "Token refresh completed: #{success_count} successful, #{failure_count} failed"

    schedule_next_run
  end

  private

  def schedule_next_run
    next_check_at = QuickbooksCredential.next_refresh_check_at
    wait_time = next_check_at - Time.current

    # Ensure we don't schedule too far in the future (max 24 hours)
    wait_time = [ wait_time, 24.hours ].min
    # Ensure we don't schedule in the past (min 1 minute)
    wait_time = [ wait_time, 1.minute ].max

    QuickbooksTokenRefreshJob.set(wait: wait_time).perform_later

    Rails.logger.info "Next QuickBooks token refresh scheduled at #{next_check_at.strftime('%Y-%m-%d %H:%M:%S')} (in #{wait_time.to_i} seconds)"
  end
end
