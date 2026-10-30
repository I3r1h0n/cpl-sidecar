#!/usr/bin/env bash
#
# Default (no arguments): run the Crystal Palace sidecar on port 60060
# With arguments: run the cpl CLI, like `docker run --rm ... image link ...`
#
set -euo pipefail

readonly CPL_HOME="${CPL_HOME:-/opt/crystalpalace}"
readonly CPL_JAR="${CPL_HOME}/crystalpalace.jar"

readonly CPL_PORT="${CPL_PORT:-60060}"
readonly CPL_INTERNAL_PORT="${CPL_INTERNAL_PORT:-60061}"
readonly CPL_BIND="${CPL_BIND:-0.0.0.0}"

java_args=()
if [ -n "${JAVA_OPTS:-}" ]; then
	# Deliberately unquoted so JAVA_OPTS can hold several flags
	# shellcheck disable=SC2206
	java_args=(${JAVA_OPTS})
fi

# CLI mode: pass every argument straight to Crystal Palace
if [ "$#" -gt 0 ]; then
	exec java "${java_args[@]}" -jar "$CPL_JAR" "$@"
fi

# Crystal Palace only binds the sidecar to 127.0.0.1 by design. 
# We usd socat to publishe it on the container interface to make docker port publish work
socat "TCP-LISTEN:${CPL_PORT},fork,reuseaddr,bind=${CPL_BIND}" \
      "TCP:127.0.0.1:${CPL_INTERNAL_PORT}" &
socat_pid=$!

# Fail fast if the forwarder could not bind
sleep 0.3
if ! kill -0 "$socat_pid" 2>/dev/null; then
	echo "crystalpalace: failed to listen on ${CPL_BIND}:${CPL_PORT}" >&2
	exit 1
fi

echo "crystalpalace: sidecar listening on ${CPL_BIND}:${CPL_PORT} (backend 127.0.0.1:${CPL_INTERNAL_PORT})" >&2

exec java "${java_args[@]}" -jar "$CPL_JAR" server -p "$CPL_INTERNAL_PORT"
