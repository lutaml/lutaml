# frozen_string_literal: true

source "https://rubygems.org"

gemspec

gem "canon"
gem "irb"
# The suite's XML engine per #534 is moxml's leptris adapter; without this
# dev dependency moxml silently falls back to nokogiri and CI never
# exercises the mandated lane. moxml enforces the >= 1.9.386.0 binding
# floor at load; the pessimistic range follows it.
gem "leptris", "~> 1.9.386"
gem "openssl", "~> 3.0"
gem "rake"
gem "rake-compiler"
gem "rspec"
gem "rubocop"
gem "rubocop-performance"
gem "rubocop-rake"
gem "rubocop-rspec"
gem "yard"
