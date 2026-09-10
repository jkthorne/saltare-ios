#!/usr/bin/env bash
# Copy the server's golden API payloads into SaltareWorkspace's test bundle.
#
# These files pin the shape of every /api/v1 serializer. The server owns them;
# regenerate there first:
#
#   cd ../saltare
#   WRITE_GOLDEN=1 bin/rails test test/serializers/api/v1/golden_payloads_test.rb
#
# then run this and `swift test --package-path Packages/SaltareWorkspace`.
#
# Only the payloads SaltareWorkspace has a model for are copied. An unread
# golden drifts silently, so GoldenPayloadTests fails if one appears here
# without a decoding case — add the model, or leave the file on the server.
set -euo pipefail

# Keep in step with the cases in GoldenPayloadTests.swift.
PAYLOADS=(agent channel document message task device_session)

root="$(cd "$(dirname "$0")/.." && pwd)"
server="${SALTARE_PATH:-$root/../saltare}"
src="$server/test/fixtures/files/api_golden"
dest="$root/Packages/SaltareWorkspace/Tests/SaltareWorkspaceTests/api_golden"

if [ ! -d "$src" ]; then
  echo "no goldens at $src" >&2
  echo "point SALTARE_PATH at a saltare checkout, or clone it beside this repo." >&2
  exit 1
fi

mkdir -p "$dest"
for payload in "${PAYLOADS[@]}"; do
  cp "$src/$payload.json" "$dest/$payload.json"
done

echo "synced ${#PAYLOADS[@]} goldens from $src"
git -C "$root" status --short -- "$dest"
