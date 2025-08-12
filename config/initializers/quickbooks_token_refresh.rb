# Start the QuickBooks token refresh job cycle when the app boots
# This ensures tokens are kept fresh even after app restarts
Rails.application.config.after_initialize do
  # Only start the job if we have QuickBooks credentials and we're not in test mode
  unless Rails.env.test? || Rails.env.development?
    if QuickbooksCredential.exists?
      # Use dynamic scheduling based on actual token expiry times
      next_check_at = QuickbooksCredential.next_refresh_check_at
      wait_time = [ (next_check_at - Time.current), 1.minute ].max

      QuickbooksTokenRefreshJob.set(wait: wait_time).perform_later
      Rails.logger.info "QuickBooks token refresh job scheduled for #{next_check_at.strftime('%Y-%m-%d %H:%M:%S')}"
    end
  end
end
