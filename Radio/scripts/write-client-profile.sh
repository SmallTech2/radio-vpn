#!/usr/bin/env bash
# Un seul assemblage PEM pour la creation et la regeneration des profils.
set -Eeuo pipefail
umask 077
CERT_NAME="${1:?Nom du certificat manquant}"
[[ "$CERT_NAME" =~ ^[a-zA-Z0-9][a-zA-Z0-9_.@-]*$ ]] || exit 1
APP_CONF="${OPENVPN_UI_CONFIG:-/opt/openvpn-ui-runtime/conf/app.conf}"
EASY_RSA=$(grep -E '^EasyRsaPath\s*=' "$APP_CONF" | cut -d= -f2 | tr -d '"[:space:]')
OPENVPN_DIR=$(grep -E '^OpenVpnPath\s*=' "$APP_CONF" | cut -d= -f2 | tr -d '"[:space:]')
CERT="$EASY_RSA/pki/issued/$CERT_NAME.crt"
openssl x509 -in "$CERT" -noout >/dev/null
openssl verify -CAfile "$EASY_RSA/pki/ca.crt" "$CERT" >/dev/null
{
  sed -E '/^[[:space:]]*<ca>[[:space:]]*$/,/^[[:space:]]*<\/ca>[[:space:]]*$/d;
    /^[[:space:]]*<cert>[[:space:]]*$/,/^[[:space:]]*<\/cert>[[:space:]]*$/d;
    /^[[:space:]]*<key>[[:space:]]*$/,/^[[:space:]]*<\/key>[[:space:]]*$/d;
    /^[[:space:]]*<tls-crypt>[[:space:]]*$/,/^[[:space:]]*<\/tls-crypt>[[:space:]]*$/d' "$OPENVPN_DIR/config/client.conf"
  printf '\n<ca>\n'; cat "$EASY_RSA/pki/ca.crt"; printf '\n</ca>\n<cert>\n'
  sed -n '/-----BEGIN CERTIFICATE-----/,/-----END CERTIFICATE-----/p' "$CERT"
  printf '</cert>\n<key>\n'; cat "$EASY_RSA/pki/private/$CERT_NAME.key"
  printf '\n</key>\n<tls-crypt>\n'; cat "$EASY_RSA/pki/ta.key"
  printf '\n</tls-crypt>\n'
} > "$OPENVPN_DIR/clients/$CERT_NAME.ovpn"
chmod 600 "$OPENVPN_DIR/clients/$CERT_NAME.ovpn"
