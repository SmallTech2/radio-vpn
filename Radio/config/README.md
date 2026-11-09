# Modèles de configuration

Ces fichiers servent au déploiement natif ; ce ne sont pas les configurations actives
d'un serveur. Le [guide utilisateur](../../docs/README.md) décrit l'installation et les chemins
d'exploitation.

| Fichier | Utilisation |
| --- | --- |
| `app.conf` | Paramètres de l'application ; le déploiement remplace les marqueurs d'IPv4 publique, réseau CIDR et identité PKI |
| `openvpn-server-config.tpl` | Modèle Go rendu par l'application pour `/etc/openvpn/server.conf` |
| `openvpn-client-config.tpl` | Modèle Go des paramètres et blocs PEM des profils clients |
| `easyrsa-vars.tpl` | Modèle des paramètres Easy-RSA |
| `openvpn-ui.service` | Unité systemd de l'interface, fichier d'environnement et dépendance à nftables |
| `nftables.conf.tpl` | Règles réseau ; `@SSH_PORTS@` reçoit les ports SSH effectifs |

Les marqueurs `@...@` sont remplacés par le script de déploiement ; les expressions
`{{ ... }}` sont rendues par l'application. Les modèles installés pour l'UI se trouvent
dans `/opt/openvpn-ui-runtime/conf`.

Le mode fourni utilise `tun0`, des IP fixes CCD et `nopool` : il ne doit pas émettre
`ifconfig-pool-persist`, qui exige un pool dynamique. Le réseau et son masque sont issus
des paramètres d'installation. nftables limite l'accès distant à TCP 8080 à `tun0` ;
l'accès local permet l'utilisation d'un tunnel SSH.

Pour la version stable, les modèles sont récupérés depuis le commit exact déclaré dans
le paquet publié. Une modification de ce dossier sur `main` ne change ni la Release
figée ni les serveurs déjà déployés.
