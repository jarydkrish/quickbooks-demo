module QuickbooksHelper
  # Returns true if we have a credential with a realm_id (i.e., connected)
  def quickbooks_connected?
    cred = QuickbooksCredential.first
    cred.present? && cred.realm_id.present?
  rescue StandardError
    false
  end


  # Detect common ENV misconfigurations without exposing actual values
  # Returns an array of issue symbols, empty when OK
  def quickbooks_env_issues
    id = ENV["INTUIT_CLIENT_ID"].to_s
    secret = ENV["INTUIT_CLIENT_SECRET"].to_s

    looks_placeholder = ->(v) { v.strip.empty? || v.match?(/\A(your_|changeme|placeholder|xxx)/i) }

    issues = []
    issues << :client_id_missing if id.strip.empty?
    issues << :client_id_placeholder if !id.strip.empty? && looks_placeholder.call(id)
    issues << :client_secret_missing if secret.strip.empty?
    issues << :client_secret_placeholder if !secret.strip.empty? && looks_placeholder.call(secret)
    issues
  end

  def quickbooks_env_configured?
    quickbooks_env_issues.empty?
  end
end
