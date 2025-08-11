require "quickbooks-ruby"

Quickbooks.sandbox_mode = !Rails.env.production?
