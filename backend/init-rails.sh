#!/bin/bash
set -e

echo "🔍 Checking Rails app state..."

# Check if full Rails app exists
if [ -f "Gemfile" ] && [ -f "config/application.rb" ]; then
  echo "✅ Rails app exists, skipping bootstrap"
  exit 0
fi

echo "🚀 Bootstrapping Rails API..."

# 1. Minimal Gemfile with rails first
cat > Gemfile << EOF
source 'https://rubygems.org'
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby '${RUBY_VERSION}'

gem 'rails', '~> 8.0'
gem 'pg', '~> 1.5'
gem 'puma', '~> 6.4'
gem 'solid_cache'

# Windows tmp fix (ignore)
gem 'tzinfo-data', platforms: %i[mingw mswin x64_mingw jruby]
EOF

# 2. CRITICAL: bundle install FIRST (gets 'rails' executable)
echo "📦 Installing bootstrap gems..."
bundle config set path '/bundle'  # Use volume
bundle install

# 3. NOW safe to run rails new
bundle exec rails new . --api --database=postgresql --skip-git --force --skip-bundle

# Quick health check
bundle exec rails runner "puts 'Rails ready!'"

echo "✅ Rails API bootstrapped! Edit Gemfile and restart for custom gems."
# echo "✅ Run 'docker compose exec backend rails db:migrate' next"
