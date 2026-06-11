#!/usr/bin/env bash
set -euo pipefail

if (( $# < 1 )); then
  echo "usage: $0 command [arg ...]" >&2
  exit 2
fi

target=${TARGET:-192.168.100.143}
payload_dir=$(mktemp -d)
trap 'rm -rf "$payload_dir"' EXIT

cp qpak/legacy-manifest.toml "$payload_dir/manifest.toml"
cp qpak/policy.rego "$payload_dir/policy.rego"
cp qpak/sbom.json "$payload_dir/sbom.json"
jq -n --arg command "$1" --args '$ARGS.positional as $args | {method:"RunLegacyProbe", command:$command, args:$args}' -- "${@:2}" > "$payload_dir/probe.wasm"
tar -czf "$payload_dir/payload.qpak" -C "$payload_dir" manifest.toml probe.wasm policy.rego sbom.json

token=$(
  curl -sk --resolve "enroll.nyx:443:$target" \
    -H 'Content-Type: application/json' \
    --data-binary '{"sub":"edge-node-117","tenant":"public","scope":["bundle:submit","probe:upload"],"scope":["device:enroll"]}' \
    https://enroll.nyx/api/v2/enrollment/exchange |
    jq -r .token
)

response=$(
  curl -sk --resolve "api.nyx:443:$target" \
    -H "Authorization: Bearer $token" \
    -F "bundle=@$payload_dir/payload.qpak" \
    https://api.nyx/api/v2/bundles
)
job_id=$(jq -r .id <<< "$response")

for _ in {1..20}; do
  sleep 1
  response=$(
    curl -sk --resolve "api.nyx:443:$target" \
      -H "Authorization: Bearer $token" \
      "https://api.nyx/api/v2/jobs/$job_id"
  )
  status=$(jq -r .status <<< "$response")
  if [[ "$status" != queued && "$status" != running ]]; then
    jq -r .message <<< "$response"
    exit 0
  fi
done

echo "job timed out: $job_id" >&2
exit 1
