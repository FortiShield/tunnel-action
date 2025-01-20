#!/bin/bash
set -euo pipefail

# Set artifact reference
scanType="${INPUT_SCAN_TYPE:-image}"
scanRef="${INPUT_SCAN_REF:-.}"
if [ -n "${INPUT_IMAGE_REF:-}" ]; then
  scanRef="${INPUT_IMAGE_REF}" # backwards compatibility
fi

# Handle tunnel ignores
if [ -n "${INPUT_TUNNELIGNORES:-}" ]; then
  ignorefile="./tunnelignores"

  # Clear the ignore file if it exists, or create a new empty file
  : > "$ignorefile"

  for f in ${INPUT_TUNNELIGNORES//,/ }; do
    if [ -f "$f" ]; then
      echo "Found ignorefile '${f}':"
      cat "${f}"
      cat "${f}" >> "$ignorefile"
    else
      echo "ERROR: cannot find ignorefile '${f}'." >&2
      exit 1
    fi
  done
  export TUNNEL_IGNOREFILE="$ignorefile"
fi

# Handle SARIF
if [ "${TUNNEL_FORMAT:-}" = "sarif" ]; then
  if [ "${INPUT_LIMIT_SEVERITIES_FOR_SARIF:-false,,}" != "true" ]; then
    echo "Building SARIF report with all severities"
    unset TUNNEL_SEVERITY
  else
    echo "Building SARIF report"
  fi
fi

# Run Tunnel
cmd=(tunnel "$scanType" "$scanRef")
echo "Running Tunnel with options: ${cmd[*]}"
"${cmd[@]}"
returnCode=$?

if [ "${TUNNEL_FORMAT:-}" = "github" ]; then
  if [ -n "${INPUT_GITHUB_PAT:-}" ]; then
    printf "\n Uploading GitHub Dependency Snapshot"
    curl -H 'Accept: application/vnd.github+json' -H "Authorization: token ${INPUT_GITHUB_PAT}" \
         "https://api.github.com/repos/$GITHUB_REPOSITORY/dependency-graph/snapshots" -d @"${TUNNEL_OUTPUT:-}"
  else
    printf "\n Failing GitHub Dependency Snapshot. Missing github-pat" >&2
  fi
fi

exit $returnCode
