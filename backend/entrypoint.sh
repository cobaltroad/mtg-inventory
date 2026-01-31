#!/bin/bash
set -euo pipefail  # Strict mode: exit on error/unset vars/bad pipes

cd /backend

# Clean Rails PID (prevents restart issues)
rm -f tmp/pids/server.pid

# Bootstrap Rails app if missing (your init script)
if [ ! -f "Gemfile" ] || [ ! -f "config/application.rb" ]; then
  echo "🚀 No Rails app found. Running init-rails.sh..."
  ./init-rails.sh
  echo "✅ Rails app bootstrapped."
fi

# Bundle install if needed (respects BUNDLE_PATH=/bundle volume)
if ! bundle check > /dev/null 2>&1; then
  echo "📦 Installing gems..."
  bundle install
fi

# Wait for DB + prepare (create/migrate/seed idempotently)
if [ "$1" = "rails" ] || [ "$1" = "./bin/rails" ]; then
  echo "⏳ Waiting for DB..."
  wait-for-it db:5432 --timeout=60 --strict -- bundle exec rails db:prepare
fi

# RAILS_MASTER_KEY check (non-fatal)
if [ -z "${RAILS_MASTER_KEY+x}" ] || [ -z "$RAILS_MASTER_KEY" ] || [ ${#RAILS_MASTER_KEY} -ne 32 ]; then
  echo "⚠️  WARNING: RAILS_MASTER_KEY missing/blank/wrong length!"
  RAILS_MASTER_KEY=$(ruby -e "require 'securerandom'; puts SecureRandom.hex(16)")
  export RAILS_MASTER_KEY
  rm -f config/credentials.yml.enc config/master.key
  echo "{}" | bin/rails runner "Rails.application.credentials.save"
  echo ""
  echo "✅ Bootstrapped with empty credentials. "
  echo "   Add the key to .env:"
  echo "     RAILS_MASTER_KEY=$RAILS_MASTER_KEY"
  echo ""
  echo "   Then re-run to load environment variables"
  echo "     docker compose up backend"
  echo ""
  echo "   Detach and save the new creentials"
  echo "     docker compose exec backend bin/rails credentials:edit"
else
  bin/rails runner "
    begin
      creds = Rails.application.credentials.to_h
      creds.reject! { |k,v| k.to_s =~ /pass|key|token|secret/i }
      if creds.empty?
        warn '⚠️  EMPTY/BOOTSTRAP credentials found.  Detach and run:'
        warn '     docker compose exec backend bin/rails credentials:edit'
      else
        puts YAML.dump(creds)
      end
    rescue
      warn '⚠️  Missing key/file (add RAILS_MASTER_KEY to .env)'
    end
  " >&2 || true
fi

# Hand off to CMD (rails server, console, etc.)
exec "$@"

