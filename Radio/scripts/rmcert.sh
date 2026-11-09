#!/usr/bin/env bash
set -Eeuo pipefail
CERT_NAME="${1:?Nom manquant}"
CERT_SERIAL="${2:?Numero de serie manquant}"
[[ "$CERT_NAME" =~ ^[a-zA-Z0-9][a-zA-Z0-9_.@-]*$ && "$CERT_SERIAL" =~ ^[a-fA-F0-9]+$ ]] || exit 1
APP_CONF="${OPENVPN_UI_CONFIG:-/opt/openvpn-ui-runtime/conf/app.conf}"
EASY_RSA=$(grep -E '^EasyRsaPath\s*=' "$APP_CONF" | cut -d= -f2 | tr -d '"[:space:]')
OPENVPN_DIR=$(grep -E '^OpenVpnPath\s*=' "$APP_CONF" | cut -d= -f2 | tr -d '"[:space:]')
STATUS=$(awk -F '\t' -v serial="$CERT_SERIAL" 'toupper($4)==toupper(serial){print $1}' "$EASY_RSA/pki/index.txt")
[[ "$STATUS" == R ]] || { echo 'Suppression refusee : certificat non revoque.' >&2; exit 1; }
# Un autre certificat valide du meme client peut exister apres renouvellement.
if ! awk -F '\t' -v cn="$CERT_NAME" '$1=="V" {n=split($6,p,"/"); for(i=1;i<=n;i++) if(p[i]=="CN="cn) found=1} END{exit !found}' "$EASY_RSA/pki/index.txt"; then
  rm -f -- "$OPENVPN_DIR/clients/$CERT_NAME.ovpn" "$OPENVPN_DIR/clients/$CERT_NAME.png" "$OPENVPN_DIR/staticclients/$CERT_NAME"
  if [[ -n "${TFA_NAME:-}" && -f "$OPENVPN_DIR/clients/oath.secrets" ]]; then
    python3 - "$OPENVPN_DIR/clients/oath.secrets" "$TFA_NAME" <<'PY'
import pathlib, sys
path = pathlib.Path(sys.argv[1])
path.write_text(''.join(line for line in path.read_text().splitlines(True)
                        if line.split(':', 1)[0] != sys.argv[2]))
PY
  fi
fi
 echo 'Fichiers clients nettoyes ; historique des revocations conserve dans la CA.'
