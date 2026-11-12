# Radio VPN

[Installation](#installation) · [Guides utilisateur](#guides-utilisateur) · [Écosystème Radio VPN](#écosystème-radio-vpn)

## Présentation

Radio VPN automatise le déploiement d’OpenVPN Community Edition et d’OpenVPN UI sur un
VPS **Debian 13 AMD64**, sans Docker ni compilation sur le serveur. L’interface Web
permet de créer les clients, de leur attribuer une adresse VPN fixe et de gérer leurs
certificats, leur renouvellement et leur révocation. Les équipements connectés
**peuvent communiquer entre eux par leurs adresses VPN privées**, sous réserve de leurs
pare-feu locaux, tout en conservant leur connexion Internet habituelle.

L’installation sécurise les accès avec SSH par clé, nftables et les profils `tls-crypt` ;
l’interface Web est accessible par VPN ou tunnel SSH. Elle configure aussi le renouvellement
de la CRL, le clavier console, la désactivation persistante d’IPv6 et la gestion des logs.
Les projets complémentaires [radio-vpn-backup](https://github.com/SmallTech2/radio-vpn-backup)
et [radio-vpn-restore](https://github.com/SmallTech2/radio-vpn-restore) permettent de
sauvegarder les données puis de reconstruire le serveur en conservant les certificats clients.
Voir le [périmètre de compatibilité](docs/ecosystem.md#périmètre-de-compatibilité).

Solution validée le 12 novembre 2026 sur Debian 13.7.

### Version stable et démarrage rapide

Version stable publiée : **[radio-v2.4](https://github.com/SmallTech2/radio-vpn/releases/tag/radio-v2.4)**.
Le [guide d’installation](docs/installation.md#télécharger-et-lancer-linstallateur-stable)
fournit la commande de téléchargement figée sur cette version, avec vérification des empreintes.

## Installation

### Installer le serveur VPN

**[Ouvrir la procédure complète d’installation sur Debian 13](docs/installation.md).**

Elle détaille les prérequis, le téléchargement, le premier lancement, le redémarrage,
la reprise manuelle, les paramètres et la validation de l’accès SSH par clé.
Utiliser un VPS vierge ; ne pas relancer l’installateur pour mettre à jour une PKI existante.
Pour reconstruire un ancien serveur, suivre le [parcours de restauration](https://github.com/SmallTech2/radio-vpn-restore/blob/main/docs/restoration.md).

## Guides utilisateur

- [Administration](docs/administration.md) : utilisation d’OpenVPN UI et gestion des clients.
- [Accéder à OpenVPN UI](docs/administration.md#accès-à-openvpn-ui) : tunnel SSH ou connexion depuis le VPN.
- [Clients, IP fixes et communication entre clients](docs/administration.md#clients-ip-fixes-et-communication) : création et distribution des profils.
- [Révocation et renouvellement](docs/administration.md#révocation-suppression-et-renouvellement-des-clients) : gestion du cycle de vie des certificats.

## Sauvegarde et restauration

radio-vpn seul n’installe pas le programme de sauvegarde. Installer d’abord celui-ci
sur le VPS, puis choisir une seule méthode de collecte NAS :

- [Installation VPS et première sauvegarde](https://github.com/SmallTech2/radio-vpn-backup/blob/main/docs/vps-installation.md).
- [Collecte Synology ABB — méthode principale](https://github.com/SmallTech2/radio-vpn-backup/blob/main/docs/abb.md#5-configurer-abb).
- [Collecteur Synology personnalisé — alternative sans ABB](https://github.com/SmallTech2/radio-vpn-backup/blob/main/docs/installation.md).
- [Reconstruction et restauration](https://github.com/SmallTech2/radio-vpn-restore/blob/main/docs/restoration.md) : réutiliser la CA et les certificats sur un serveur reconstruit avec le même réseau VPN.

Après restauration, réinstaller le programme de sauvegarde et vérifier la collecte NAS.

## Sécurité et maintenance

- [Sécurité](docs/security.md) : SSH par clé, console de secours, IPv6 et filtrage nftables.
- [Maintenance](docs/maintenance.md) : services, diagnostic, CRL et mises à jour.
- [Gestion automatique des logs](docs/maintenance.md#gestion-automatique-des-logs) : rotation et limites journald.
- [Reconstruire un serveur](docs/maintenance.md#reconstruire-un-serveur) : précautions et conservation des identités.

## Références techniques

- [Déploiement](Radio/README.md) : organisation de l’installateur.
- [Scripts](Radio/scripts/README.md) : scripts auxiliaires et durcissement SSH.
- [Modèles de configuration](Radio/config/README.md) : OpenVPN, SSH et systemd.
- [Suivi technique de maintenance](docs/VALIDATION.md) : validations et limites.
- [Index documentaire](docs/README.md).

### Licence et crédits

Projet dérivé de [d3vilh/openvpn-ui](https://github.com/d3vilh/openvpn-ui), distribué
par Radio Bonheur sous [licence MIT](LICENSE). Les copyrights et attributions d’Adam
Wałach et de Mr. Philipp (d3vilh) sont conservés. Les notices des dépendances restent
dans `vendor/`, avec leurs versions dans `go.mod` et `go.sum`.

## Écosystème Radio VPN

- [radio-vpn](https://github.com/SmallTech2/radio-vpn) : [installer un serveur VPN](docs/installation.md).
- [radio-vpn-backup](https://github.com/SmallTech2/radio-vpn-backup) : [sauvegarder ce serveur](https://github.com/SmallTech2/radio-vpn-backup/blob/main/docs/vps-installation.md).
- [radio-vpn-restore](https://github.com/SmallTech2/radio-vpn-restore) : [reconstruire et restaurer](https://github.com/SmallTech2/radio-vpn-restore/blob/main/docs/restoration.md).

La [présentation de l’écosystème](docs/ecosystem.md) explique les rôles et dépendances des trois projets.
