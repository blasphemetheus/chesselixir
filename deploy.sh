#!/usr/bin/env bash
set -e
git pull origin main
mix deps.get --only prod
MIX_ENV=prod mix compile
MIX_ENV=prod mix ecto.migrate
sudo systemctl restart chesselixir
