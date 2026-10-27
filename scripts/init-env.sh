#!/usr/bin/env bash
# Creates .env from .env.example with random secrets. Never overwrites an existing .env.
set -euo pipefail
cd "$(dirname "$0")/.."

if [[ -f .env ]]; then
  echo "[env] .env ya existe — no se modifica."
  exit 0
fi

random_secret() { od -An -N20 -tx1 /dev/urandom | tr -d ' \n'; }

while IFS= read -r line || [[ -n $line ]]; do
  if [[ $line =~ ^([A-Z0-9_]+_(PASSWORD|SECRET_KEY))= ]]; then
    echo "${BASH_REMATCH[1]}=$(random_secret)"
  else
    echo "$line"
  fi
done < .env.example > .env
chmod 600 .env
echo "[env] .env creado con secretos aleatorios (chmod 600)."
