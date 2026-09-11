#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Sync an OpenAPI file from a remote URL.

Usage:
  ./scripts/sync-openapi.sh --url <remote-url> --out <local-path> [options]

Required:
  --url <remote-url>      Remote OpenAPI URL
  --out <local-path>      Destination file path (for example, openapi/switch.openapi.json)

Options:
  --header <value>        Extra HTTP header. You can pass this flag multiple times.
  --token-env <name>      Env var that contains a bearer token for Authorization header.
  --dry-run               Download and validate without writing the output file.
  -h, --help              Show this help message.
EOF
}

url=""
out=""
dry_run="false"
token_env=""
headers=()

while (($# > 0)); do
  case "$1" in
    --url)
      url="${2:-}"
      shift 2
      ;;
    --out)
      out="${2:-}"
      shift 2
      ;;
    --header)
      headers+=("${2:-}")
      shift 2
      ;;
    --token-env)
      token_env="${2:-}"
      shift 2
      ;;
    --dry-run)
      dry_run="true"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ -z "$url" || -z "$out" ]]; then
  echo "You must provide --url and --out." >&2
  usage
  exit 1
fi

if [[ -n "$token_env" ]]; then
  token_value="${!token_env:-}"
  if [[ -z "$token_value" ]]; then
    echo "Environment variable '$token_env' is not set or empty." >&2
    exit 1
  fi
  headers+=("Authorization: Bearer $token_value")
fi

tmp_file="$(mktemp)"
trap 'rm -f "$tmp_file"' EXIT

curl_args=(--fail --location --silent --show-error --output "$tmp_file" "$url")
if [[ ${#headers[@]} -gt 0 ]]; then
  for header in "${headers[@]}"; do
    curl_args=(--header "$header" "${curl_args[@]}")
  done
fi

curl "${curl_args[@]}"

if [[ "$out" == *.json ]]; then
  # Validate JSON responses early to avoid checking in malformed specs.
  python3 - "$tmp_file" <<'PY'
import json
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
with path.open("r", encoding="utf-8") as handle:
    payload = json.load(handle)

# Write normalized JSON to keep repository diffs readable and deterministic.
with path.open("w", encoding="utf-8") as handle:
    json.dump(payload, handle, indent=2, ensure_ascii=False)
    handle.write("\n")
PY
fi

if [[ "$dry_run" == "true" ]]; then
  echo "Downloaded and validated: $url"
  echo "Dry run enabled; no file was written."
  exit 0
fi

mkdir -p "$(dirname "$out")"

if [[ -f "$out" ]] && cmp -s "$tmp_file" "$out"; then
  echo "No changes detected: $out"
  exit 0
fi

mv "$tmp_file" "$out"
echo "Synced OpenAPI spec to: $out"

