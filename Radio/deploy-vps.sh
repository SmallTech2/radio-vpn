#!/usr/bin/env bash
# Radio Bonheur - Debian 13 AMD64, OpenVPN natif. Aucun VPS n'est modifie hors execution explicite.
# Usage : sudo bash deploy-vps.sh
set -Eeuo pipefail
umask 077
REPO='SmallTech2/radio-vpn'
RELEASE_TAG="${RADIO_RELEASE_TAG:-radio-v2.4}"
SOURCE_REF="${RADIO_SOURCE_REF:-}"
INSTALL_ROOT='/opt/openvpn-ui-runtime'
PREPARATION_STATE='/var/lib/radio-vpn/debian-upgrade-boot-id'
TMP=''
FIREWALL_PENDING=false
log(){ printf '\n==> %s\n' "$*"; }
die(){ printf '\nERREUR : %s\n' "$*" >&2; exit 1; }
cleanup(){
  local status=$?
  if $FIREWALL_PENDING; then
    echo 'Echec : arret des services VPN/UI et restauration du pare-feu precedent.' >&2
    /usr/local/sbin/radio-restore-firewall || true
  fi
  [[ -z "$TMP" ]] || rm -rf -- "$TMP"
  return "$status"
}
configure_console_keyboard(){
  local keyboard_configured=false
  if [[ -s /etc/default/keyboard ]]; then keyboard_configured=true; fi
  log 'Configuration du clavier console'
  apt-get update
  DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends console-setup keyboard-configuration
  if ! $keyboard_configured; then
    dpkg-reconfigure keyboard-configuration
  fi
  # Le deploiement peut etre lance en SSH, hors d'une console Linux.
  setupcon --force
}
disable_ipv6(){
  local config=/etc/sysctl.d/99-radio-disable-ipv6.conf setting value connections
  log 'Desactivation persistante d IPv6 : serveur IPv4 uniquement'
  # sudo peut retirer SSH_CONNECTION : verifier aussi les sessions SSH IPv6 actives.
  connections=$(ss -H -6 -tnp state established) || die 'Impossible de verifier les sessions SSH IPv6.'
  [[ "$connections" != *'("sshd'* ]] || die 'Une session SSH IPv6 est active : utiliser SSH en IPv4 et fermer les sessions SSH IPv6 avant de poursuivre.'
  install -d -m 755 /etc/sysctl.d
  printf 'net.ipv6.conf.all.disable_ipv6 = 1\nnet.ipv6.conf.default.disable_ipv6 = 1\n' > "$config"
  chmod 644 "$config"
  if [[ -d /proc/sys/net/ipv6/conf ]]; then
    sysctl -p "$config"
    for setting in /proc/sys/net/ipv6/conf/*/disable_ipv6; do
      read -r value < "$setting"
      [[ "$value" == 1 ]] || die "IPv6 reste actif : $setting"
    done
  else
    log 'IPv6 deja indisponible dans le noyau'
  fi
}
require_password(){
  local one two
  local LC_ALL=C.UTF-8
  while :; do
    IFS= read -r -s -p "$1 (8 caracteres min.) : " one </dev/tty; printf '\n' >/dev/tty
    IFS= read -r -s -p 'Confirmer : ' two </dev/tty; printf '\n' >/dev/tty
    [[ "$one" == "$two" ]] || { echo 'Saisies differentes.'; continue; }
    [[ ${#one} -ge 8 ]] || { echo 'Mot de passe trop court.'; continue; }
    REPLY="$one"; return
  done
}
require_admin_user(){
  local name
  while :; do
    read -r -p 'Nom du compte administrateur Linux [technicien] : ' name </dev/tty
    name="${name:-technicien}"
    [[ "$name" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]] || { echo 'Nom attendu : 1 a 32 caracteres, minuscules/chiffres/_/-, debutant par une lettre ou _.'; continue; }
    if getent passwd "$name" >/dev/null || getent group "$name" >/dev/null; then
      echo 'Ce nom correspond deja a un compte ou un groupe. Choisir un nouveau nom.'
      continue
    fi
    REPLY="$name"; return 0
  done
}
fetch(){ curl --fail --silent --show-error --location --retry 3 --proto '=https' --proto-redir '=https' --tlsv1.2 "$1" -o "$2"; }

ipv4_number(){
  local part value=0
  local -a parts
  [[ "$1" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || return 1
  IFS=. read -r -a parts <<< "$1"
  for part in "${parts[@]}"; do
    [[ "$part" == 0 || "$part" != 0* ]] || return 1
    (( 10#$part <= 255 )) || return 1
    value=$(( (value << 8) | 10#$part ))
  done
  REPLY=$value
}
ipv4_text(){ printf '%d.%d.%d.%d' "$(( ($1 >> 24) & 255 ))" "$(( ($1 >> 16) & 255 ))" "$(( ($1 >> 8) & 255 ))" "$(( $1 & 255 ))"; }
private_ipv4(){
  (( ($1 >= 0x0a000000 && $1 <= 0x0affffff) ||
     ($1 >= 0xac100000 && $1 <= 0xac1fffff) ||
     ($1 >= 0xc0a80000 && $1 <= 0xc0a8ffff) ))
}
public_ipv4(){
  ipv4_number "$1" || return 1
  ! private_ipv4 "$REPLY" || return 1
  (( REPLY >= 0x01000000 && REPLY < 0xe0000000 &&
     (REPLY >> 24) != 127 && (REPLY >> 16) != 0xa9fe &&
     !(REPLY >= 0x64400000 && REPLY <= 0x647fffff) ))
}
vpn_network(){
  local address bits mask last
  [[ "$1" =~ ^([^/]+)/([0-9]{1,2})$ ]] || return 1
  address="${BASH_REMATCH[1]}"; bits=$((10#${BASH_REMATCH[2]}))
  # Limites de la directive OpenVPN "server" avec une interface tun.
  (( bits >= 16 && bits <= 29 )) || return 1
  ipv4_number "$address" || return 1
  address=$REPLY; mask=$(( (0xffffffff << (32-bits)) & 0xffffffff ))
  (( (address & mask) == address )) || return 1
  last=$((address | (0xffffffff ^ mask)))
  private_ipv4 "$address" && private_ipv4 "$last" || return 1
  # Le serveur utilise toujours la premiere adresse utilisable (reseau + 1).
  REPLY="$(ipv4_text "$address")/$bits $(ipv4_text "$mask") $(ipv4_text "$((address+1))") $bits"
}
network_conflict(){
  local candidate="$1" bits base end route rest route_base route_bits route_end
  bits="${candidate#*/}"; ipv4_number "${candidate%/*}"; base=$REPLY
  end=$((base | (0xffffffff >> bits)))
  while read -r route rest; do
    [[ "$route" != default && "$route" != 0.0.0.0/0 ]] || continue
    [[ "$route" == */* ]] || route="$route/32"
    route_bits="${route#*/}"
    [[ "$route_bits" =~ ^[0-9]+$ ]] && (( route_bits <= 32 )) || continue
    ipv4_number "${route%/*}" || continue
    route_base=$REPLY; route_end=$((route_base | (0xffffffff >> route_bits)))
    if (( base <= route_end && route_base <= end )); then
      echo "Reseau en conflit avec la route existante $route." >&2; return 0
    fi
  done <<< "$2"
  return 1
}
wait_for_tun_address(){
  local attempt
  # systemd peut annoncer le service actif avant la configuration de tun0.
  for attempt in {1..10}; do
    if ip -j -4 address show dev tun0 2>/dev/null | python3 -c '
import json, sys
try:
    interfaces = json.load(sys.stdin)
except ValueError:
    sys.exit(1)
sys.exit(0 if any(
    address.get("family") == "inet" and address.get("local") == sys.argv[1]
    and address.get("prefixlen") == int(sys.argv[2])
    for interface in interfaces for address in interface.get("addr_info", [])
) else 1)
' "$1" "$2"; then return 0; fi
    if (( attempt < 10 )); then sleep 1; fi
  done
  return 1
}
require_secure_admin_ssh(){
  local admin_user="$1" public_ip="$2" answer ssh_port server_ip cursor journal
  [[ -x /usr/local/bin/radio-secure-ssh ]] || die 'Commande /usr/local/bin/radio-secure-ssh absente ou non executable.'
  ssh_port=$(awk '{print $4}' <<< "${SSH_CONNECTION:-}")
  if [[ ! "$ssh_port" =~ ^[0-9]+$ ]]; then
    ssh_port=$(/usr/sbin/sshd -T | awk '$1=="port" && !found {print $2; found=1}')
  fi
  [[ "$ssh_port" =~ ^[0-9]+$ ]] || die 'Port SSH introuvable pour la validation par cle.'
  server_ip=$(awk '{print $3}' <<< "${SSH_CONNECTION:-}")
  server_ip="${server_ip:-$public_ip}"
  # Seules les authentifications posterieures a ce point pourront servir de preuve.
  journal=$(journalctl -b -u ssh -n 1 --show-cursor --no-pager -o cat) || die 'Journal SSH inaccessible ; acces existants conserves.'
  cursor=$(awk '/^-- cursor: / {print $3}' <<< "$journal")
  [[ -n "$cursor" ]] || die 'Position du journal SSH introuvable ; acces existants conserves.'
  log 'Validation SSH par cle obligatoire avant la suite de l installation'
  echo 'Garder cette session ouverte. Depuis un AUTRE terminal du poste administrateur :'
  printf 'ssh -4 -o ControlMaster=no -o ControlPath=none -o PreferredAuthentications=publickey -o PasswordAuthentication=no -o KbdInteractiveAuthentication=no -p %s %s@%s\n' "$ssh_port" "$admin_user" "$public_ip"
  echo 'Ajouter -i CHEMIN_CLE_PRIVEE si necessaire. Ne jamais copier la cle privee sur le VPS.'
  echo 'Garder la nouvelle session ouverte, puis confirmer ici. Aucune valeur a recopier.'
  while :; do
    read -r -p 'La nouvelle connexion par cle fonctionne-t-elle ? [oui/N] : ' answer </dev/tty || die 'Validation SSH interrompue ; installation non terminee.'
    [[ "$answer" == oui || "$answer" == OUI ]] || continue
    if SUDO_USER="$admin_user" /usr/local/bin/radio-secure-ssh --after-cursor "$cursor" "$server_ip" "$ssh_port"; then
      return 0
    fi
    echo 'Durcissement non confirme : corriger le probleme puis verifier une nouvelle connexion par cle.'
  done
}
confirm_install(){
  local answer
  read -r -p 'Commencer les modifications systeme ? [oui/N] : ' answer </dev/tty
  [[ "$answer" == oui || "$answer" == OUI ]]
}

prepare_debian(){
  local boot_id prepared_boot_id
  read -r boot_id < /proc/sys/kernel/random/boot_id
  if [[ -f "$PREPARATION_STATE" ]]; then
    read -r prepared_boot_id < "$PREPARATION_STATE"
    [[ -n "$prepared_boot_id" ]] || die 'Etat de preparation Debian invalide.'
    if [[ "$prepared_boot_id" != "$boot_id" ]]; then
      log 'Debian deja mis a niveau et redemarre : poursuite de l installation'
      return 0
    fi
    echo 'La mise a niveau est terminee, mais le VPS doit encore redemarrer.'
    confirm_install || { echo 'Redemarrage reporte.'; exit 0; }
  else
    log 'Preparation Debian : full-upgrade, autoremove --purge, puis redemarrage'
    echo 'Apres reconnexion SSH, relancer : sudo bash deploy-vps.sh'
    confirm_install || { echo 'Preparation annulee, aucune modification systeme.'; exit 0; }
    DEBIAN_FRONTEND=noninteractive apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get -y -o Dpkg::Options::=--force-confold full-upgrade
    DEBIAN_FRONTEND=noninteractive apt-get -y autoremove --purge
    # Ecrit uniquement apres succes ; le boot_id permet de verifier le redemarrage.
    install -d -m 700 "$(dirname "$PREPARATION_STATE")"
    printf '%s\n' "$boot_id" > "$PREPARATION_STATE"
  fi
  echo 'Redemarrage du VPS. Apres reconnexion SSH, relancer : sudo bash deploy-vps.sh'
  systemctl reboot
  exit 0
}

install_radio(){
  local public_ip="${1:-}" net="${2:-}" pubkey org email admin_user admin_home detected='' routes mask server_ip prefix
  [[ ! -e "$INSTALL_ROOT" && ! -e /etc/openvpn/server.conf && ! -e /etc/openvpn/pki ]] || die 'Installation existante detectee. Refus de remplacer.'
  [[ ! -f /etc/radio-vpn-deployed ]] || die 'Deploiement deja effectue.'
  [[ "$RELEASE_TAG" =~ ^[a-zA-Z0-9._-]+$ ]] || die 'Nom de Release invalide.'
  [[ -z "$SOURCE_REF" || ( "$SOURCE_REF" =~ ^[a-zA-Z0-9._/-]+$ && "$SOURCE_REF" != *..* ) ]] || die 'Reference Git invalide.'
  [[ "${SSH_CONNECTION:-${SSH_CLIENT:-}}" != *:* ]] || die 'Session SSH IPv6 detectee : reconnecter en IPv4 avec ssh -4 avant de lancer l installation.'
  prepare_debian
  command -v ip >/dev/null || die 'La commande ip (iproute2) est necessaire pour verifier les routes avant installation.'
  routes=$(ip -4 route show table all) || die 'Impossible de lire les routes IPv4.'
  detected=$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<NF;i++) if($i=="src") {print $(i+1); exit}}') || true
  if ! public_ipv4 "$detected"; then
    detected=''
    if command -v curl >/dev/null; then
      detected=$(curl -4 --fail --silent --show-error --max-time 5 --proto '=https' https://api.ipify.org 2>/dev/null) || detected=''
    fi
    public_ipv4 "$detected" || detected=''
  fi
  while :; do
    if [[ -z "$public_ip" ]]; then
      read -r -p "IPv4 publique du VPS${detected:+ [$detected]} : " public_ip </dev/tty
      public_ip="${public_ip:-$detected}"
    fi
    public_ipv4 "$public_ip" && break
    echo 'IPv4 publique invalide.'; public_ip=''
  done
  # Les formes courtes 10.1, 10.2 et 10.3 utilisent un masque /16.
  [[ ! "$net" =~ ^10\.[123]$ ]] || net="$net.0.0/16"
  while :; do
    [[ -n "$net" ]] || read -r -p 'Reseau VPN prive en CIDR (ex. 10.3.0.0/16) : ' net </dev/tty
    if vpn_network "$net"; then
      read -r net mask server_ip prefix <<< "$REPLY"
      if ! network_conflict "$net" "$routes"; then break; fi
    else
      echo 'Adresse reseau RFC1918 attendue, prefixe /16 a /29 (limites OpenVPN).'
    fi
    net=''
  done
  require_admin_user; admin_user="$REPLY"; unset REPLY
  admin_home="/home/$admin_user"
  read -r -p 'Cle SSH PUBLIQUE ED25519 du poste administrateur (obligatoire) : ' pubkey </dev/tty
  [[ "$pubkey" =~ ^ssh-ed25519[[:space:]]+[A-Za-z0-9+/=]+([[:space:]].*)?$ ]] || die 'Cle ED25519 invalide.'
  read -r -p 'Organisation PKI [Radio Bonheur] : ' org </dev/tty; org="${org:-Radio Bonheur}"
  read -r -p 'Email PKI de votre organisation (obligatoire) : ' email </dev/tty
  [[ "$org" =~ ^[a-zA-Z0-9\ ._@+-]+$ ]] || die 'Organisation : lettres, chiffres, espaces et ._@+- uniquement.'
  [[ "$email" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+$ ]] || die 'Email invalide.'
  printf '\nIPv4 publique : %s\nReseau VPN : %s\nServeur VPN : %s (premiere adresse utilisable)\nRelease : %s\n' "$public_ip" "$net" "$server_ip" "$RELEASE_TAG"
  printf 'Compte administrateur Linux : %s\n' "$admin_user"
  echo 'Etapes : clavier, mots de passe, cle SSH et identite PKI, puis installation native IPv4 uniquement (IPv6 desactive).'
  confirm_install || { echo 'Installation annulee, aucune modification systeme.'; return 0; }
  configure_console_keyboard
  require_password "Mot de passe du compte $admin_user"; local admin_pw="$REPLY"; unset REPLY
  require_password 'Mot de passe admin OpenVPN UI'; local gui_pw="$REPLY"; unset REPLY
  printf '\nIPv4 publique : %s\nReseau VPN : %s\nServeur VPN : %s\nOrganisation : %s\nEmail : %s\n' "$public_ip" "$net" "$server_ip" "$org" "$email"
  printf 'Compte administrateur Linux : %s\n' "$admin_user"
  confirm_install || { echo 'Installation annulee apres configuration du clavier.'; return 0; }

  log 'Dependances Debian (sans compilation sur le VPS)'
  export DEBIAN_FRONTEND=noninteractive
  apt-get update
  apt-get install -y --no-install-recommends sudo openssh-server ca-certificates curl unzip tar \
    openvpn easy-rsa nftables openssl python3 oathtool qrencode iproute2 util-linux procps logrotate
  TMP="$(mktemp -d)"; mkdir -p "$TMP/src" "$TMP/bin"
  printf '%s\n' "$pubkey" > "$TMP/admin.pub"
  ssh-keygen -lf "$TMP/admin.pub" >/dev/null || die 'Cle publique SSH illisible.'

  log 'Release figee : verification SHA-256 avant extraction'
  local archive='radio-openvpn-ui-linux-amd64.zip' compiled_commit source_commit
  local release_url="https://github.com/$REPO/releases/download/$RELEASE_TAG"
  fetch "$release_url/$archive" "$TMP/$archive"
  fetch "$release_url/$archive.sha256" "$TMP/$archive.sha256"
  (cd "$TMP" && sha256sum -c "$archive.sha256") || die 'SHA256 de l archive invalide.'
  unzip -q "$TMP/$archive" -d "$TMP/bin"
  for f in openvpn-ui openvpn-ui.sha256 source-commit.txt SHA256SUMS; do
    [[ -s "$TMP/bin/$f" ]] || die "Release incomplete : $f absent. Recompiler les correctifs."
  done
  (cd "$TMP/bin" && sha256sum -c SHA256SUMS && sha256sum -c openvpn-ui.sha256) || die 'Contenu de Release invalide.'
  compiled_commit="$(cat "$TMP/bin/source-commit.txt")"
  [[ "$compiled_commit" =~ ^[0-9a-f]{40}$ ]] || die 'Commit du binaire invalide.'
  source_commit="$compiled_commit"
  # Le paquet indique les revisions exactes du binaire et des scripts de deploiement.
  [[ ! "$RELEASE_TAG" =~ ^radio-v[0-9]+([.][0-9]+)*$ || -s "$TMP/bin/deployment-source-commit.txt" ]] || die 'Commit de deploiement absent de la Release stable.'
  if [[ -s "$TMP/bin/deployment-source-commit.txt" ]]; then
    source_commit="$(cat "$TMP/bin/deployment-source-commit.txt")"
    [[ "$source_commit" =~ ^[0-9a-f]{40}$ ]] || die 'Commit du deploiement invalide.'
  fi
  if [[ -n "$SOURCE_REF" ]]; then
    local encoded_ref
    encoded_ref=$(python3 -c 'import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1], safe=""))' "$SOURCE_REF")
    fetch "https://api.github.com/repos/$REPO/commits/$encoded_ref" "$TMP/commit.json"
    local requested_commit
    requested_commit=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["sha"])' "$TMP/commit.json")
    [[ "$requested_commit" == "$source_commit" ]] || die 'La revision demandee ne correspond pas aux sources de deploiement de la Release.'
  fi
  fetch "https://github.com/$REPO/archive/$source_commit.tar.gz" "$TMP/source.tgz"
  tar -xzf "$TMP/source.tgz" -C "$TMP/src" --strip-components=1
  for f in genclient.sh write-client-profile.sh generate_ca_and_server_certs.sh oath.sh remove.sh renew.sh restart.sh revoke.sh rmcert.sh secure-ssh.sh; do
    [[ -s "$TMP/src/Radio/scripts/$f" ]] || die "Script absent : $f"
  done
  for f in app.conf openvpn-server-config.tpl openvpn-client-config.tpl easyrsa-vars.tpl openvpn-ui.service nftables.conf.tpl openvpn.logrotate 99-radio-limits.conf; do
    [[ -s "$TMP/src/Radio/config/$f" ]] || die "Modele absent : $f"
  done
  for f in static views swagger; do [[ -d "$TMP/bin/$f" ]] || die "Ressources UI absentes : $f"; done
  SSH_HARDENING_COMMIT="$source_commit"
  bash -n "$TMP/src/Radio/scripts/secure-ssh.sh"

  log "Compte $admin_user, sudo et preparation SSH"
  useradd -m -U -d "$admin_home" -s /bin/bash "$admin_user"
  usermod -aG sudo "$admin_user"
  printf '%s:%s\n' "$admin_user" "$admin_pw" | chpasswd; unset admin_pw
  install -d -m 700 -o "$admin_user" -g "$admin_user" "$admin_home/.ssh"
  install -m 600 -o "$admin_user" -g "$admin_user" "$TMP/admin.pub" "$admin_home/.ssh/authorized_keys"
  install -d -m 755 /etc/ssh/sshd_config.d
  install -d -m 755 /run/sshd
  # Ne pas rouvrir les mots de passe si la configuration Debian les interdit deja.
  if [[ ! -e /etc/ssh/sshd_config.d/00-radio.conf ]]; then
    printf 'PubkeyAuthentication yes\n' > /etc/ssh/sshd_config.d/00-radio.conf
  fi
  /usr/sbin/sshd -t
  systemctl enable --now ssh
  systemctl reload ssh
  install -d -m 755 /usr/local/bin
  install -m 755 "$TMP/src/Radio/scripts/secure-ssh.sh" /usr/local/bin/radio-secure-ssh
  require_secure_admin_ssh "$admin_user" "$public_ip"
  disable_ipv6

  log 'Installation du runtime et generation synchronisee de la base GUI et des configurations'
  install -d -m 755 "$INSTALL_ROOT" "$INSTALL_ROOT/conf" /opt/scripts /etc/openvpn/config \
    /etc/openvpn/clients /etc/openvpn/staticclients /var/log/openvpn
  install -d -m 700 "$INSTALL_ROOT/db"
  configure_logs
  install -m 755 "$TMP/bin/openvpn-ui" "$INSTALL_ROOT/openvpn-ui"
  cp -a "$TMP/bin/static" "$TMP/bin/views" "$TMP/bin/swagger" "$INSTALL_ROOT/"
  install -m 644 "$TMP/src/LICENSE" "$INSTALL_ROOT/LICENSE"
  sed -e "s/@PUBLIC_IP@/$public_ip/g" -e "s|@VPN_NETWORK@|$net|g" \
    -e "s/@PKI_ORG@/$org/g" -e "s/@PKI_EMAIL@/$email/g" \
    "$TMP/src/Radio/config/app.conf" > "$INSTALL_ROOT/conf/app.conf"
  for f in openvpn-server-config.tpl openvpn-client-config.tpl easyrsa-vars.tpl; do
    install -m 644 "$TMP/src/Radio/config/$f" "$INSTALL_ROOT/conf/$f"
  done
  # Le mode nopool exclut la persistance d'un pool dynamique.
  sed -i '/^[[:space:]]*ifconfig-pool-persist[[:space:]]/d' "$INSTALL_ROOT/conf/openvpn-server-config.tpl"
  install -m 755 "$TMP/src/Radio/scripts/"*.sh /opt/scripts/
  ln -s /usr/bin/qrencode /opt/scripts/qrencode
  install -d -m 755 /usr/share/easy-rsa/pki
  ln -s /usr/share/easy-rsa/pki /etc/openvpn/pki
  # EnvironmentFile systemd : conserver espaces, guillemets et antislashs du mot de passe.
  local gui_pw_escaped="${gui_pw//\\/\\\\}"
  gui_pw_escaped="${gui_pw_escaped//\"/\\\"}"
  printf 'OPENVPN_ADMIN_PASSWORD="%s"\n' "$gui_pw_escaped" > /etc/openvpn-ui.env
  unset gui_pw_escaped
  chmod 600 /etc/openvpn-ui.env
  (cd "$INSTALL_ROOT"; OPENVPN_ADMIN_USERNAME=admin OPENVPN_ADMIN_PASSWORD="$gui_pw" ./openvpn-ui -initialize-only)
  unset gui_pw
  [[ -s "$INSTALL_ROOT/db/data.db" && -s /usr/share/easy-rsa/pki/vars && -s /etc/openvpn/server.conf && -s /etc/openvpn/config/client.conf ]] || die 'Initialisation GUI incomplete.'
  cp /usr/share/easy-rsa/pki/vars /etc/openvpn/config/easy-rsa.vars
  install -m 644 "$TMP/src/Radio/config/easyrsa-vars.tpl" /etc/openvpn/config/easy-rsa.vars.template

  log 'Initialisation de la PKI unique'
  /opt/scripts/generate_ca_and_server_certs.sh init_all
  openssl verify -CAfile /etc/openvpn/pki/ca.crt /etc/openvpn/pki/issued/server.crt
  openssl crl -in /etc/openvpn/pki/crl.pem -noout -nextupdate | python3 -c \
    'import datetime,sys; expiry=datetime.datetime.strptime(sys.stdin.read().strip().split("=",1)[1], "%b %d %H:%M:%S %Y %Z").replace(tzinfo=datetime.timezone.utc); assert expiry > datetime.datetime.now(datetime.timezone.utc)+datetime.timedelta(days=7), "CRL trop courte"'
  install -m 644 "$TMP/src/Radio/config/openvpn-ui.service" /etc/systemd/system/openvpn-ui.service
  install_crl_timer
  systemctl daemon-reload
  systemctl start radio-renew-crl.service
  systemctl enable --now radio-renew-crl.timer

  log 'Activation persistante du pare-feu avec retour arriere'
  activate_firewall
  systemctl enable --now openvpn@server.service
  systemctl is-active --quiet openvpn@server.service || die 'OpenVPN ne demarre pas.'
  wait_for_tun_address "$server_ip" "$prefix" || die 'Adresse tun0 incorrecte.'
  ss -lun | grep -q ':1194 ' || die 'UDP 1194 absent.'
  systemctl enable --now openvpn-ui.service
  systemctl is-active --quiet openvpn-ui.service || die 'OpenVPN UI ne demarre pas.'
  curl --fail --silent --show-error --retry 5 --retry-connrefused --retry-delay 1 --max-time 10 http://127.0.0.1:8080/login >/dev/null
  /usr/sbin/sshd -t
  systemctl is-active --quiet ssh || die 'SSH inactif.'
  systemctl stop radio-firewall-rollback.timer
  [[ ! -f /run/radio-firewall-backup/rolled-back ]] || die 'Le retour arriere du pare-feu a ete declenche.'
  FIREWALL_PENDING=false
  rm -rf -- /run/radio-firewall-backup

  printf 'release_tag=%s\nrelease_source_commit=%s\nbinary_source_commit=%s\nssh_hardening_source_commit=%s\npublic_ip=%s\nnetwork=%s\n' "$RELEASE_TAG" "$source_commit" "$compiled_commit" "$SSH_HARDENING_COMMIT" "$public_ip" "$net" > /etc/radio-vpn-deployed
  log 'Installation terminee : OpenVPN actif, UI protegee, CRL planifiee.'
  echo "GUI depuis le VPN : http://$server_ip:8080"
  echo "Tunnel SSH : ssh -L 8080:127.0.0.1:8080 $admin_user@$public_ip"
  echo "Creer les clients avec une IPv4 fixe du reseau $net. Aucun redirect-gateway."
}

configure_logs(){
  log 'Rotation OpenVPN et limites du journal systemd'
  install -d -m 755 -o root -g root /etc/logrotate.d /etc/systemd/journald.conf.d
  install -m 644 -o root -g root "$TMP/src/Radio/config/openvpn.logrotate" /etc/logrotate.d/openvpn
  install -m 644 -o root -g root "$TMP/src/Radio/config/99-radio-limits.conf" /etc/systemd/journald.conf.d/99-radio-limits.conf
  logrotate --debug /etc/logrotate.d/openvpn
  systemctl restart systemd-journald.service
  systemctl enable --now logrotate.timer
}

install_crl_timer(){
  cat > /usr/local/sbin/radio-renew-crl <<'CRL'
#!/usr/bin/env bash
set -Eeuo pipefail
export EASYRSA_BATCH=1
cd /usr/share/easy-rsa
[[ -s pki/ca.crt ]] || { echo 'CA absente' >&2; exit 1; }
./easyrsa gen-crl
chmod 644 pki/crl.pem
openssl crl -in pki/crl.pem -noout -nextupdate
CRL
  chmod 700 /usr/local/sbin/radio-renew-crl
  cat > /etc/systemd/system/radio-renew-crl.service <<'UNIT'
[Unit]
Description=Radio Bonheur - renouvellement de la CRL
[Service]
Type=oneshot
ExecStart=/usr/local/sbin/radio-renew-crl
UNIT
  cat > /etc/systemd/system/radio-renew-crl.timer <<'UNIT'
[Unit]
Description=Radio Bonheur - renouvellement hebdomadaire de la CRL
[Timer]
OnCalendar=weekly
Persistent=true
RandomizedDelaySec=30min
[Install]
WantedBy=timers.target
UNIT
}

activate_firewall(){
  local ports
  ports=$({ /usr/sbin/sshd -T | awk '$1=="port" {print $2}'; [[ -z "${SSH_CONNECTION:-}" ]] || awk '{print $4}' <<< "$SSH_CONNECTION"; } | sort -nu | paste -sd,)
  [[ "$ports" =~ ^[0-9]+(,[0-9]+)*$ ]] || die 'Ports SSH introuvables.'
  sed "s/@SSH_PORTS@/$ports/g" "$TMP/src/Radio/config/nftables.conf.tpl" > "$TMP/nftables.conf"
  nft -c -f "$TMP/nftables.conf"
  install -d -m 700 /run/radio-firewall-backup
  { printf 'flush ruleset\n'; nft list ruleset; } > /run/radio-firewall-backup/rules.nft
  if [[ -f /etc/nftables.conf ]]; then cp -p /etc/nftables.conf /run/radio-firewall-backup/config; fi
  if systemctl is-enabled --quiet nftables; then touch /run/radio-firewall-backup/enabled; fi
  cat > /usr/local/sbin/radio-restore-firewall <<'ROLLBACK'
#!/usr/bin/env bash
set -Eeuo pipefail
[[ -d /run/radio-firewall-backup ]] || exit 0
touch /run/radio-firewall-backup/rolled-back
systemctl stop openvpn-ui.service openvpn@server.service || true
nft -f /run/radio-firewall-backup/rules.nft
if [[ -f /run/radio-firewall-backup/config ]]; then
  cp -p /run/radio-firewall-backup/config /etc/nftables.conf
else
  rm -f /etc/nftables.conf
fi
if [[ ! -f /run/radio-firewall-backup/enabled ]]; then systemctl disable nftables; fi
systemctl stop radio-firewall-rollback.timer || true
ROLLBACK
  chmod 700 /usr/local/sbin/radio-restore-firewall
  systemd-run --quiet --unit=radio-firewall-rollback --on-active=3min /usr/local/sbin/radio-restore-firewall
  FIREWALL_PENDING=true
  install -m 600 "$TMP/nftables.conf" /etc/nftables.conf
  nft -f /etc/nftables.conf
  systemctl enable nftables
  systemctl start nftables
}

main(){
  [[ $EUID -eq 0 ]] || die 'Executer en root.'
  [[ -t 0 ]] || die 'Un terminal interactif est necessaire.'
  . /etc/os-release
  [[ $ID == debian && $VERSION_ID == 13 && $(uname -m) == x86_64 ]] || die 'Debian 13 AMD64 uniquement.'
  trap cleanup EXIT
  trap 'echo "Echec du deploiement, ligne $LINENO." >&2' ERR
  trap 'exit 1' HUP INT TERM
  case "${1:-install}" in
    install) [[ $# -eq 0 ]] || shift; [[ $# -le 2 ]] || die "Usage : sudo bash $0"; install_radio "$@" ;;
    *) die "Usage : sudo bash $0" ;;
  esac
}
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then main "$@"; fi
