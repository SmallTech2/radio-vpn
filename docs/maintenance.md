# Maintenance

[Accueil et installation](../README.md#installer-le-serveur-vpn) · [Tous les guides](README.md) · [Écosystème](ecosystem.md)

Les commandes ci-dessous concernent un serveur déjà installé.

## Gestion automatique des logs

Le paquet `logrotate` est installé explicitement et `logrotate.timer` est activé.
Le fichier `/etc/logrotate.d/openvpn` configure la rotation quotidienne de
`/var/log/openvpn/openvpn.log`, avec conservation de **7 archives compressées**.
Les fichiers absents ou vides sont ignorés. `openvpn-status.log` est un fichier
d'état réécrit automatiquement : il n'est pas inclus dans cette rotation.

La méthode `copytruncate` copie le journal puis tronque le fichier actif : OpenVPN
continue d'écrire sans redémarrage. Elle présente un faible risque de perte de lignes
entre la copie et la troncature. La rotation quotidienne **n'est pas un plafond strict
de taille** : un journal très actif peut grossir entre deux exécutions.

`/etc/systemd/journald.conf.d/99-radio-limits.conf` fixe `SystemMaxUse=200M` pour
le stockage persistant et `RuntimeMaxUse=50M` pour le stockage volatil. Ces limites
concernent journald, pas les fichiers OpenVPN. Journald supprime les anciens fichiers
archivés pour respecter ses limites ; ses fichiers actifs et les autres journaux du
système peuvent encore occuper de l'espace. Surveillez donc aussi l'espace disque.

Commandes de contrôle (le mode `--debug` ne déclenche aucune rotation) :

```bash
sudo logrotate --debug /etc/logrotate.d/openvpn
systemctl list-timers --all logrotate.timer
systemctl --no-pager status logrotate.timer
sudo systemd-analyze cat-config systemd/journald.conf
sudo journalctl --disk-usage
sudo du -sh /var/log/openvpn /var/log/journal /run/log/journal 2>/dev/null
df -h /
```

### Appliquer à un VPS déjà installé

Aucune réinstallation ni aucun redémarrage d'OpenVPN n'est nécessaire. Exécutez :

```bash
sudo apt update
sudo apt install -y logrotate
sudo install -d -m 755 -o root -g root /etc/logrotate.d /etc/systemd/journald.conf.d
sudo tee /etc/logrotate.d/openvpn >/dev/null <<'EOF'
/var/log/openvpn/openvpn.log {
    daily
    rotate 7
    compress
    missingok
    notifempty
    copytruncate
}
EOF
sudo tee /etc/systemd/journald.conf.d/99-radio-limits.conf >/dev/null <<'EOF'
[Journal]
SystemMaxUse=200M
RuntimeMaxUse=50M
EOF
sudo chown root:root /etc/logrotate.d/openvpn /etc/systemd/journald.conf.d/99-radio-limits.conf
sudo chmod 644 /etc/logrotate.d/openvpn /etc/systemd/journald.conf.d/99-radio-limits.conf
sudo logrotate --debug /etc/logrotate.d/openvpn
sudo systemctl restart systemd-journald.service
sudo systemctl enable --now logrotate.timer
```

Vérifiez ensuite les contrôles ci-dessus. Seul journald est redémarré ; les services
OpenVPN et OpenVPN UI ne sont pas interrompus.

## Renouvellement automatique de la CRL

Commandes de contrôle et de renouvellement :

```bash
sudo openssl crl -in /etc/openvpn/pki/crl.pem -noout -lastupdate -nextupdate
sudo openssl crl -in /etc/openvpn/pki/crl.pem -noout -text
sudo systemctl start radio-renew-crl.service
sudo journalctl -u radio-renew-crl.service -n 50 --no-pager
systemctl list-timers --all radio-renew-crl.timer
```

Le service exécute Easy-RSA `gen-crl` et rend la CRL lisible par OpenVPN.
Le timer `radio-renew-crl.timer` est hebdomadaire et persistant, avec un délai aléatoire
de trente minutes au maximum. Le déclenchement manuel par `systemctl start` est utile
pour une opération de maintenance ou un contrôle.

Une session déjà établie n'est pas nécessairement interrompue dès la publication de la CRL.
Ne pas utiliser les commandes de suppression de PKI de la GUI pour retirer un seul client.

## Fichiers et services


| Élément | Rôle |
| --- | --- |
| `/opt/openvpn-ui-runtime` | Binaire, ressources UI, configuration et base SQLite |
| `/opt/scripts` | Scripts nécessaires aux operations de la GUI |
| `/etc/openvpn/server.conf` | Configuration du serveur VPN |
| `/etc/openvpn/config/client.conf` | Modèle utilisé pour produire les profils clients |
| `/etc/openvpn/staticclients` | IP fixes CCD |
| `/etc/openvpn/clients` | Profils clients confidentiels |
| `/usr/share/easy-rsa/pki` | PKI unique ; `/etc/openvpn/pki` est un lien vers elle |
| `/etc/openvpn-ui.env` | Mot de passe initial UI, accès root uniquement |
| `/etc/radio-vpn-deployed` | Release, commits du déploiement et du binaire, IP et réseau |

`openvpn@server.service` lance OpenVPN, `openvpn-ui.service` lance l'interface,
`radio-renew-crl.service` régénère la CRL et `radio-renew-crl.timer` planifie cette opération.
## Diagnostic

```bash
systemctl --no-pager status openvpn@server openvpn-ui nftables radio-renew-crl.timer
sudo journalctl -u openvpn@server -u openvpn-ui -n 100 --no-pager
sudo tail -n 100 /var/log/openvpn/openvpn.log
ip -j -4 address show dev tun0
sudo ss -lunp
sudo nft list ruleset
sysctl net.ipv4.ip_forward net.ipv6.conf.all.disable_ipv6 net.ipv6.conf.default.disable_ipv6
sudo /usr/sbin/sshd -t
sudo cat /etc/radio-vpn-deployed
```

## Reconstruire un serveur


Pour conserver les identités existantes, utiliser une archive de
[radio-vpn-backup](https://github.com/SmallTech2/radio-vpn-backup), reconstruire le serveur
avec radio-vpn puis suivre la [procédure radio-vpn-restore](https://github.com/SmallTech2/radio-vpn-restore/blob/main/docs/restoration.md).
Le réseau VPN de destination doit correspondre à celui de la sauvegarde. Les accès SSH
et le pare-feu du nouveau serveur sont conservés ; la PKI provisoire est remplacée par
la PKI sauvegardée. Ne pas recréer les certificats clients pour cette opération.

Sans sauvegarde de la PKI et des données UI, une installation vierge ne récupère pas
les identités précédentes : il faut créer et distribuer de nouveaux profils. La copie
locale du dépôt et les assets GitHub ne contiennent pas la PKI d’exploitation.
Aucun système de sauvegarde VPS n’est installé par radio-vpn seul. Commencer par
[l’installation de radio-vpn-backup sur le VPS](https://github.com/SmallTech2/radio-vpn-backup/blob/main/docs/vps-installation.md),
puis choisir la collecte [ABB](https://github.com/SmallTech2/radio-vpn-backup/blob/main/docs/abb.md#5-configurer-abb)
ou [personnalisée](https://github.com/SmallTech2/radio-vpn-backup/blob/main/docs/installation.md).

## Mises à jour

Les mises à jour Debian relèvent de l’administration du VPS. Garder une session SSH
ouverte et une sauvegarde récente avant une intervention :

```bash
sudo apt update
sudo apt upgrade
```

Ces commandes peuvent demander des décisions ou un redémarrage ; suivre leurs messages.
Pour l’application, consulter la Release et sa notice avant toute substitution. Il
n’existe pas de commande de mise à jour applicative en place fournie par l’installateur.
Ne pas le relancer sur une PKI existante pour mettre le serveur à jour. Modifier le
clone Git ne modifie ni le binaire ni les fichiers déjà installés sur le VPS.

## Maintenance et fichiers de référence


Suivez les mises à jour de sécurité Debian, l'état des services et les dates d'expiration
des certificats et de la CRL. Conservez une session SSH ouverte pendant les interventions.
Une modification de modèle dans le dépôt ne met pas à jour un serveur déjà installé.

La Release publiée conserve le binaire, le paquet de déploiement et leurs empreintes.
Le paquet distingue les sources du binaire (`source-commit.txt`) de celles des scripts
et modèles (`deployment-source-commit.txt`). Les sources et les dépendances Go sont
conservées dans le dépôt, avec `go.mod`, `go.sum` et `vendor/`.
Les paquets système restent fournis par les miroirs Debian et peuvent évoluer.


Pour les téléchargements, utilisez uniquement la référence figée indiquée dans le
[README principal](../README.md#version-stable-et-démarrage-rapide). Les fichiers d'une
Release publiée et son tag doivent rester inchangés.
