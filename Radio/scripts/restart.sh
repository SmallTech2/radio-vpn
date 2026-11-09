#!/bin/bash
# Radio Bonheur - Redemarrage natif OpenVPN / OpenVPN UI sous systemd
set -euo pipefail

ACTION="${1:-openvpn-server}"

case "$ACTION" in
    openvpn-server)
        systemctl restart openvpn@server.service
        if ! systemctl is-active --quiet openvpn@server.service; then
            echo "ERREUR : openvpn@server.service n'est pas actif apres redemarrage." >&2
            exit 1
        fi
        echo "OpenVPN redemarre : openvpn@server.service actif."
        ;;
    openvpn-ui)
        # Executer le redemarrage apres la fin de la requete HTTP courante.
        # Ceci confirme la programmation, pas le succes du futur redemarrage.
        systemd-run --quiet --unit="radio-openvpn-ui-restart-$(date +%s)-$$" \
            --on-active=2s /usr/bin/systemctl restart openvpn-ui.service
        echo "Redemarrage d'OpenVPN UI programme dans 2 secondes."
        ;;
    *)
        echo "ERREUR : action inconnue : $ACTION" >&2
        exit 1
        ;;
esac
