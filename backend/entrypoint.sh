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

# Hand off to CMD (rails server, console, etc.)
exec "$@"

