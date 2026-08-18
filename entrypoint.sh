#!/bin/sh

# Start the sandbox API (required for every Blaxel sandbox)
/usr/local/bin/sandbox-api &

# Wait for sandbox API to be ready before doing anything else
echo "Waiting for sandbox API..."
while ! nc -z 127.0.0.1 8080; do
  sleep 0.1
done
echo "Sandbox API ready"

# Hermes itself is NOT auto-started here on purpose. Hermes is an
# interactive/agentic process you'll typically drive via the sandbox API's
# /process endpoint from your orchestrator (Daytona → Blaxel migration
# context), not something that should free-run on every sandbox boot.
#
# To launch Hermes from your orchestrator once the sandbox is DEPLOYED:
#
#   curl http://127.0.0.1:8080/process -X POST \
#     -H "Content-Type: application/json" \
#     -d '{
#       "workingDir": "/usr/local/lib/hermes-agent",
#       "command": "./venv/bin/python run_agent.py",
#       "waitForCompletion": false
#     }'
#
# NOTE: use ./venv/bin/python, not system python — Hermes's deps (pyyaml,
# etc.) live in its own uv-managed virtualenv, not on the system Python path.
# Alternatively, use the "hermes" launcher the installer already put on
# PATH at /usr/local/bin/hermes, which handles venv activation for you.
#
# If you DO want Hermes to boot automatically with the sandbox instead,
# uncomment the block below:
#
# echo "Starting Hermes Agent..."
# curl http://127.0.0.1:8080/process -X POST \
#   -H "Content-Type: application/json" \
#   -d '{"workingDir": "/usr/local/lib/hermes-agent", "command": "./venv/bin/python run_agent.py", "waitForCompletion": false}'

# Keep the container running
wait
