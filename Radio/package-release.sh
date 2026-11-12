#!/usr/bin/env bash
# Archive du binaire et des ressources, avec leurs revisions Git explicites.
set -Eeuo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT"
BINARY="${1:-dist/openvpn-ui}"
[[ -s "$BINARY" ]] || { echo 'Binaire absent.' >&2; exit 1; }
STAGE=$(mktemp -d)
trap 'rm -rf -- "$STAGE"' EXIT
cp "$BINARY" "$STAGE/openvpn-ui"
cp -a static views swagger Radio docs README.md LICENSE VERSION "$STAGE/"
DEPLOYMENT_COMMIT=$(git rev-parse HEAD)
printf '%s\n' "${BINARY_SOURCE_COMMIT:-$DEPLOYMENT_COMMIT}" > "$STAGE/source-commit.txt"
printf '%s\n' "$DEPLOYMENT_COMMIT" > "$STAGE/deployment-source-commit.txt"
if [[ -n "${VALIDATED_DEPLOYMENT_COMMIT:-}" ]]; then
  printf '%s\n' "$VALIDATED_DEPLOYMENT_COMMIT" > "$STAGE/validated-deployment-commit.txt"
fi
(cd "$STAGE"; sha256sum openvpn-ui > openvpn-ui.sha256)
(cd "$STAGE"; find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS)
mkdir -p dist
python3 - "$STAGE" dist/radio-openvpn-ui-linux-amd64.zip <<'PY'
import pathlib, sys, zipfile
root = pathlib.Path(sys.argv[1])
with zipfile.ZipFile(sys.argv[2], 'w', compression=zipfile.ZIP_DEFLATED) as archive:
    for path in sorted(root.rglob('*')):
        if path.is_file():
            name = path.relative_to(root).as_posix()
            info = zipfile.ZipInfo(name, date_time=(1980, 1, 1, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            mode = 0o755 if name == 'openvpn-ui' or name.endswith('.sh') else 0o644
            info.external_attr = (0o100000 | mode) << 16
            archive.writestr(info, path.read_bytes())
PY
(cd dist; sha256sum radio-openvpn-ui-linux-amd64.zip > radio-openvpn-ui-linux-amd64.zip.sha256)
