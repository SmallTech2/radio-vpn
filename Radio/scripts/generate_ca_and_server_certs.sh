#!/usr/bin/env bash
# Une seule PKI : /etc/openvpn/pki pointe sur le repertoire Easy-RSA.
set -Eeuo pipefail
umask 077
ACTION="${1:?Action PKI manquante}"
APP_CONF="${OPENVPN_UI_CONFIG:-/opt/openvpn-ui-runtime/conf/app.conf}"
EASY_RSA=$(grep -E '^EasyRsaPath\s*=' "$APP_CONF" | cut -d= -f2 | tr -d '"[:space:]')
OPENVPN_DIR=$(grep -E '^OpenVpnPath\s*=' "$APP_CONF" | cut -d= -f2 | tr -d '"[:space:]')
cd "$EASY_RSA"
export EASYRSA_BATCH=1
export EASYRSA_PKI="$EASY_RSA/pki"

init_pki() {
  [[ ! -e "$EASYRSA_PKI/ca.crt" ]] || { echo 'PKI existante : reinitialisation refusee.' >&2; exit 1; }
  ./easyrsa init-pki
  cp "$OPENVPN_DIR/config/easy-rsa.vars" "$EASYRSA_PKI/vars"
  # La CRL est relue par OpenVPN apres abandon des privileges root.
  chmod 755 "$EASYRSA_PKI"
}
build_ca() { [[ -s "$EASYRSA_PKI/ca.crt" ]] || ./easyrsa build-ca nopass; }
gen_req() {
  if [[ ! -s "$EASYRSA_PKI/issued/server.crt" ]]; then
    ./easyrsa gen-req server nopass
    ./easyrsa sign-req server server
  fi
}
gen_dh() { [[ -s "$EASYRSA_PKI/dh.pem" ]] || ./easyrsa gen-dh; }
gen_ta() { [[ -s "$EASYRSA_PKI/ta.key" ]] || openvpn --genkey secret "$EASYRSA_PKI/ta.key"; }
gen_crl() { ./easyrsa gen-crl; chmod 644 "$EASYRSA_PKI/crl.pem"; }

case "$ACTION" in
  init-pki) init_pki ;;
  copy_vars) cp "$OPENVPN_DIR/config/easy-rsa.vars" "$EASYRSA_PKI/vars" ;;
  build_ca) build_ca ;;
  gen_req) gen_req ;;
  gen_dh) gen_dh ;;
  gen_ta) gen_ta ;;
  gen_crl) gen_crl ;;
  init_all) init_pki; build_ca; gen_req; gen_dh; gen_ta; gen_crl ;;
  *) echo "Action PKI inconnue : $ACTION" >&2; exit 1 ;;
esac
