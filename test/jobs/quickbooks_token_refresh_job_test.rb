require "test_helper"

class QuickbooksTokenRefreshJobTest < ActiveJob::TestCase
  def setup
    @credential = QuickbooksCredential.create!(
      access_token: "test_access_token",
      refresh_token: "test_refresh_token",
      realm_id: "123456789",
      access_token_expires_at: 5.minutes.from_now, # Expires soon, needs refresh
      refresh_token_expires_at: 100.days.from_now,
      updated_at: 10.minutes.ago
    )
  end

  test "schedules next job run" do
    assert_enqueued_jobs 1, only: QuickbooksTokenRefreshJob do
      QuickbooksTokenRefreshJob.perform_now
    end
  end

  test "identifies credentials that need refresh" do
    # This credential needs refresh (expires in 5 minutes)
    assert @credential.needs_refresh?

    # Create a credential that doesn't need refresh (expires in 1 hour)
    fresh_credential = QuickbooksCredential.create!(
      access_token: "fresh_token",
      refresh_token: "fresh_refresh_token",
      realm_id: "987654321",
      access_token_expires_at: 1.hour.from_now,
      refresh_token_expires_at: 100.days.from_now,
      updated_at: 10.minutes.ago
    )

    assert_not fresh_credential.needs_refresh?
  end

  test "validates refresh token is still valid" do
    assert @credential.refresh_token_valid?

    # Create credential with expired refresh token
    expired_credential = QuickbooksCredential.create!(
      access_token: "expired_access_token",
      refresh_token: "expired_refresh_token",
      realm_id: "111222333",
      access_token_expires_at: 5.minutes.from_now,
      refresh_token_expires_at: 1.day.ago, # Expired
      updated_at: 10.minutes.ago
    )

    assert_not expired_credential.refresh_token_valid?
  end

  test "handles missing refresh token gracefully" do
    credential_no_refresh = QuickbooksCredential.create!(
      access_token: "test_access_token",
      refresh_token: nil,
      realm_id: "444555666",
      access_token_expires_at: 5.minutes.from_now,
      updated_at: 10.minutes.ago
    )

    assert_not credential_no_refresh.refresh_token_valid?
  end

  test "logs appropriate messages when no tokens need refresh" do
    # Update credential to not need refresh (expires in 1 hour)
    @credential.update!(access_token_expires_at: 1.hour.from_now)

    assert_enqueued_jobs 1, only: QuickbooksTokenRefreshJob do
      QuickbooksTokenRefreshJob.perform_now
    end
  end

  test "calculates refresh time correctly" do
    # Token expires in 1 hour, should refresh in 50 minutes
    credential = QuickbooksCredential.create!(
      access_token: "test_token",
      refresh_token: "test_refresh",
      realm_id: "123",
      access_token_expires_at: 1.hour.from_now,
      refresh_token_expires_at: 100.days.from_now
    )

    refresh_at = credential.refresh_at
    expected_refresh_at = credential.access_token_expires_at - 10.minutes

    # Allow for small time differences in test execution
    assert_in_delta expected_refresh_at.to_i, refresh_at.to_i, 5
  end

  test "calculates next refresh check time" do
    # Clear existing credentials
    QuickbooksCredential.destroy_all

    # Create credential expiring in 1 hour
    QuickbooksCredential.create!(
      access_token: "token1",
      refresh_token: "refresh1",
      realm_id: "123",
      access_token_expires_at: 1.hour.from_now,
      refresh_token_expires_at: 100.days.from_now
    )

    next_check = QuickbooksCredential.next_refresh_check_at
    expected_check = 50.minutes.from_now

    # Allow for small time differences in test execution
    assert_in_delta expected_check.to_i, next_check.to_i, 60
  end
end
