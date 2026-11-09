#!/usr/bin/env bash
set -Eeuo pipefail
CERT_NAME="${1:?Nom manquant}"
CERT_SERIAL="${2:?Numero de serie manquant}"
[[ "$CERT_NAME" =~ ^[a-zA-Z0-9][a-zA-Z0-9_.@-]*$ && "$CERT_SERIAL" =~ ^[a-fA-F0-9]+$ ]] || exit 1
APP_CONF="${OPENVPN_UI_CONFIG:-/opt/openvpn-ui-runtime/conf/app.conf}"
EASY_RSA=$(grep -E '^EasyRsaPath\s*=' "$APP_CONF" | cut -d= -f2 | tr -d '"[:space:]')
OPENVPN_DIR=$(grep -E '^OpenVpnPath\s*=' "$APP_CONF" | cut -d= -f2 | tr -d '"[:space:]')
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
cd "$EASY_RSA"
export EASYRSA_BATCH=1
STATUS=$(awk -F '\t' -v serial="$CERT_SERIAL" 'toupper($4)==toupper(serial){print $1}' pki/index.txt)
[[ "$STATUS" =~ ^[VER]$ ]] || { echo 'Certificat absent ou serie ambigue.' >&2; exit 1; }

revoke_record(){
  # OpenSSL compare le sujet du certificat avec l'index. Les metadonnees GUI
  # doivent etre retirees pendant cette comparaison puis restaurees, meme sur erreur.
  python3 - "$1" "$CERT_NAME" "$CERT_SERIAL" <<'PY'
import pathlib, subprocess, sys
path = pathlib.Path('pki/index.txt')
serial = sys.argv[3].upper()
records = [line.split('\t') for line in path.read_text().splitlines()]
metadata = ''
for record in records:
    if record[3].upper() == serial and '/name=' in record[5]:
        subject, suffix = record[5].split('/name=', 1)
        metadata = '/name=' + suffix
        record[5] = subject
path.write_text(''.join('\t'.join(record) + '\n' for record in records))
try:
    subprocess.run(['./easyrsa', sys.argv[1], sys.argv[2]], check=True)
finally:
    records = [line.split('\t') for line in path.read_text().splitlines()]
    for record in records:
        if record[3].upper() == serial and metadata:
            record[5] = record[5].split('/name=', 1)[0] + metadata
    path.write_text(''.join('\t'.join(record) + '\n' for record in records))
PY
}

if [[ "$STATUS" != R ]]; then
  FOUND=false
  for kind in issued renewed/issued; do
    file="pki/$kind/$CERT_NAME.crt"
    [[ -s "$file" ]] || continue
    serial=$(openssl x509 -in "$file" -noout -serial)
    [[ "${serial#serial=}" == "${CERT_SERIAL^^}" ]] || continue
    if [[ "$kind" == issued ]]; then
      revoke_record revoke-issued
      rm -f -- "$OPENVPN_DIR/clients/$CERT_NAME.ovpn"
    else
      revoke_record revoke-renewed
      bash "$SCRIPT_DIR/write-client-profile.sh" "$CERT_NAME"
    fi
    FOUND=true
    break
  done
  $FOUND || { echo 'Le fichier du certificat ne correspond pas a la serie.' >&2; exit 1; }
fi
# Ne jamais supprimer les entrees R : elles alimentent toutes les futures CRL.
./easyrsa gen-crl
chmod 644 pki/crl.pem
 echo 'Certificat revoque ; historique CA conserve.'
