# Documentation Radio VPN

La version stable officielle est indiquée dans le
[README principal](../README.md#version-stable-et-démarrage-rapide).
Le guide d'installation reprend sa commande de téléchargement figée.

## Guides utilisateur

- [Installation](installation.md) : prérequis, téléchargement publié, redémarrage et paramètres.
- [Administration](administration.md) : interface Web, tunnel SSH, clients à IP fixes et révocation.
- [Sécurité](security.md) : filtrage entrant nftables, durcissement SSH et accès à l’interface par tunnel SSH ou depuis le VPN.
- [Maintenance](maintenance.md) : CRL, services, diagnostic et reconstruction.

## Références techniques

- [Déploiement](../Radio/README.md).
- [Scripts](../Radio/scripts/README.md).
- [Modèles de configuration](../Radio/config/README.md).

Les scripts et configurations restent dans `Radio/`. Le dossier `test/` contient
uniquement les tests ; les notices des dépendances restent dans `vendor/`.
