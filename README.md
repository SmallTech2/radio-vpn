# Radio VPN — OpenVPN natif sur Debian 13

Radio VPN installe OpenVPN Community Edition et OpenVPN UI sur un VPS **Debian 13
AMD64**, avec Easy-RSA, systemd et nftables, sans Docker ni compilation sur le serveur.

Projet dérivé de [d3vilh/openvpn-ui](https://github.com/d3vilh/openvpn-ui), distribué
par Radio Bonheur sous [licence MIT](LICENSE). Les copyrights et attributions
d'Adam Wałach et de Mr. Philipp (d3vilh) sont conservés.

## Objectif et résultat de l'installation

Relier des postes ou équipements distants dans un réseau privé IPv4 à adresses fixes,
administré depuis une interface Web. Les clients communiquent entre eux avec
`client-to-client` et conservent leur connexion Internet habituelle.

Après une installation réussie, le serveur dispose :

- D'un compte administrateur Linux choisi par l'utilisateur, avec sudo et accès SSH par clé ED25519 vérifié.
- D'OpenVPN et d'OpenVPN UI démarrés et gérés par systemd.
- D'une PKI Easy-RSA unique, du certificat serveur et d'un renouvellement automatique de la CRL.
- D'un pare-feu nftables : SSH et UDP 1194 accessibles publiquement ; interface Web accessible par VPN ou tunnel SSH.
- D'IPv6 désactivé de façon persistante, après validation de l'accès SSH en IPv4.
- Des composants du clavier console Debian et de l'application de la disposition configurée avec `setupcon --force`.
- D'une [gestion automatique des logs](docs/maintenance.md#gestion-automatique-des-logs) : rotation OpenVPN et limites journald.

Créez ensuite les clients dans l'interface, attribuez leurs IP fixes et téléchargez
leurs profils `.ovpn` avec `tls-crypt`. L'ajout d'un client ne redémarre pas OpenVPN.
La liste principale masque les certificats révoqués sans effacer leur révocation.
Le serveur n'est pas configuré comme passerelle Internet pour les clients.

## Version stable et démarrage rapide

Version publiée : **[radio-v2.4](https://github.com/SmallTech2/radio-vpn/releases/tag/radio-v2.4)**.
Les scripts, le binaire Linux AMD64 et les ressources sont associés au même commit.
Les empreintes SHA-256 sont fournies avec les fichiers de la Release.

Prévoyez un VPS vierge Debian 13 AMD64, une IPv4 publique fixe, un accès SSH en IPv4
avec droits root/sudo et la clé publique ED25519 du poste administrateur.
Le pare-feu de l'hébergeur doit autoriser le port SSH utilisé et UDP 1194.

```bash
sudo apt update
sudo apt install -y curl
curl --fail --location --proto '=https' --proto-redir '=https' \
  https://raw.githubusercontent.com/SmallTech2/radio-vpn/radio-v2.4/Radio/deploy-vps.sh \
  -o deploy-vps.sh
sudo bash deploy-vps.sh
```

Avec une session `root`, omettez `sudo`. Gardez le fichier téléchargé dans le même
répertoire : après la préparation Debian et le redémarrage, reconnectez-vous en IPv4
et relancez `sudo bash deploy-vps.sh`. La reprise est manuelle.

L'installateur demande les paramètres du réseau, l'identité PKI, le nom du compte
Linux et les mots de passe. Une nouvelle connexion SSH par clé doit être ouverte et
confirmée ; sa preuve est vérifiée automatiquement dans le journal avant durcissement.

Consultez les guides : [installation](docs/installation.md),
[administration](docs/administration.md), [sécurité](docs/security.md) et
[maintenance](docs/maintenance.md). `Radio/` contient les scripts et modèles du déploiement.

## Périmètre et vérifications

Le déploiement cible un serveur IPv4 AMD64 et un réseau privé RFC1918 de `/16` à `/29`.
L'adresse du serveur est la première adresse utilisable du réseau choisi. Les clients
utilisent des adresses fixes. L'installateur refuse de remplacer une installation ou
une PKI existante.

Les tests automatisés contrôlent la syntaxe Bash, le code Go, l'initialisation SQLite,
les profils clients, la PKI et la CRL, ainsi que les parcours SSH et IPv6 simulés.
Ils ne constituent pas une validation complète sur VPS réel, notamment après redémarrage.
Le contrôle réel porte aussi sur le clavier de la console, les accès SSH et Web, le
filtrage réseau, la communication entre clients et la persistance de la révocation.
Les paquets système sont fournis par les miroirs Debian.

## Licence et crédits

La [licence MIT](LICENSE), les copyrights et les attributions du projet d'origine
s'appliquent. Les licences des dépendances sont conservées dans `vendor/` ; leurs
versions sont décrites par `go.mod` et `go.sum`.
