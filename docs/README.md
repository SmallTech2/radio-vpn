# Documentation Radio VPN

[Accueil et installation](../README.md#installer-le-serveur-vpn) · [Écosystème](ecosystem.md)

La version stable officielle est indiquée dans le
[README principal](../README.md#version-stable-et-démarrage-rapide).
Le guide d'installation reprend sa commande de téléchargement figée.

## Guides utilisateur

- [Écosystème](ecosystem.md) : rôles des trois projets et parcours de reconstruction.
- [Installation](installation.md) : prérequis, téléchargement publié, redémarrage et paramètres.
- [Administration](administration.md) : interface Web, tunnel SSH, clients à IP fixes et révocation.
- [Sécurité](security.md) : filtrage entrant nftables, durcissement SSH et accès à l’interface par tunnel SSH ou depuis le VPN.
- [Maintenance](maintenance.md) : CRL, services, diagnostic et reconstruction.

## Sauvegarde et restauration

Installer d’abord le programme de sauvegarde sur le VPS, puis configurer une collecte :

- [Installation VPS et première sauvegarde](https://github.com/SmallTech2/radio-vpn-backup/blob/main/docs/vps-installation.md).
- [Collecte Synology ABB](https://github.com/SmallTech2/radio-vpn-backup/blob/main/docs/abb.md#5-configurer-abb).
- [Collecteur Synology personnalisé](https://github.com/SmallTech2/radio-vpn-backup/blob/main/docs/installation.md).
- [Reconstruction et restauration](https://github.com/SmallTech2/radio-vpn-restore/blob/main/docs/restoration.md).

## Références techniques

- [Déploiement](../Radio/README.md).
- [Scripts](../Radio/scripts/README.md).
- [Modèles de configuration](../Radio/config/README.md).

- [Suivi technique de maintenance](VALIDATION.md).

Les scripts et configurations restent dans `Radio/` ; les notices des dépendances
restent dans `vendor/`.
