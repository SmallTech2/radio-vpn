# Radio VPN — OpenVPN natif sur Debian 13

Radio VPN installe OpenVPN Community Edition et OpenVPN UI sur un VPS **Debian 13
AMD64**, avec Easy-RSA, systemd et nftables, sans Docker ni compilation sur le serveur.
Il relie des équipements distants dans un réseau privé IPv4 à adresses fixes, sans
remplacer leur connexion Internet habituelle.

Solution validée le 12 novembre 2026 sur Debian 13.7.

## Écosystème Radio VPN

Ce dépôt est le point d’entrée des trois projets :

| Projet | Fonction | Procédure |
| --- | --- | --- |
| [radio-vpn](https://github.com/SmallTech2/radio-vpn) | Installer le serveur de référence | [Installation](docs/installation.md) |
| [radio-vpn-backup](https://github.com/SmallTech2/radio-vpn-backup) | Préparer et collecter ses sauvegardes | [Sauvegarde avec Synology ABB](https://github.com/SmallTech2/radio-vpn-backup/blob/main/docs/abb.md) |
| [radio-vpn-restore](https://github.com/SmallTech2/radio-vpn-restore) | Restaurer sur un serveur reconstruit avec radio-vpn | [Restauration](https://github.com/SmallTech2/radio-vpn-restore/blob/main/docs/restoration.md) |

**Installation → sauvegarde → reconstruction → restauration.** La
[présentation de l’écosystème](docs/ecosystem.md) précise les dépendances et le périmètre
commun. Une installation OpenVPN ou une sauvegarde provenant d’un autre outil n’est
pas garantie compatible ; cela ne constitue pas une impossibilité technique absolue.

## Résultat de l’installation

- Compte administrateur Linux choisi par l’utilisateur, sudo et SSH par clé ED25519.
- OpenVPN et OpenVPN UI gérés par systemd ; interface accessible par VPN ou tunnel SSH.
- PKI Easy-RSA unique, profils clients avec `tls-crypt`, IP fixes et renouvellement automatique de la CRL.
- nftables : SSH et UDP 1194 accessibles publiquement ; TCP 8080 protégé.
- Désactivation persistante d’IPv6 après vérification de l’accès SSH en IPv4.
- Configuration du clavier console et [gestion automatique des logs](docs/maintenance.md#gestion-automatique-des-logs).

Le serveur utilise la première adresse du réseau privé choisi, de `/16` à `/29`.
Les clients communiquent par `client-to-client`. Le serveur n’est pas une passerelle Internet.
L’ajout d’un client dans l’UI ne redémarre pas OpenVPN. La révocation reste dans la PKI,
même lorsque le certificat est masqué dans la liste principale.

## Version stable et démarrage rapide

Version publiée : **[radio-v2.4](https://github.com/SmallTech2/radio-vpn/releases/tag/radio-v2.4)**,
avec paquet Linux AMD64, binaire, références des sources et empreintes SHA-256.

Sur un **VPS vierge Debian 13 AMD64**, avec une IPv4 publique et les droits sudo :

```bash
sudo apt update
sudo apt install -y curl
cd "$HOME"
curl --fail --location --proto '=https' --proto-redir '=https' \
  https://raw.githubusercontent.com/SmallTech2/radio-vpn/radio-v2.4/Radio/deploy-vps.sh \
  -o deploy-vps.sh
sudo bash deploy-vps.sh
```

En session root, omettre `sudo`. Autoriser le port SSH utilisé et UDP 1194 chez l’hébergeur.
Après la préparation Debian et le redémarrage, se reconnecter en IPv4 puis relancer le
même fichier avec `sudo bash deploy-vps.sh`. La reprise est manuelle.

L’installateur demande l’IP publique, le réseau privé, le compte Linux, sa clé publique,
l’identité PKI et les mots de passe. Garder la session ouverte et établir la nouvelle
connexion par clé demandée avant le durcissement SSH. Il refuse une installation ou
une PKI existante : utiliser radio-vpn-restore pour rétablir les identités sauvegardées.

## Guides

[Installation](docs/installation.md) · [Administration](docs/administration.md) ·
[Sécurité](docs/security.md) · [Maintenance et mises à jour](docs/maintenance.md) ·
[Écosystème](docs/ecosystem.md).

## Licence et crédits

Projet dérivé de [d3vilh/openvpn-ui](https://github.com/d3vilh/openvpn-ui), distribué
par Radio Bonheur sous [licence MIT](LICENSE). Les copyrights et attributions d’Adam
Wałach et de Mr. Philipp (d3vilh) sont conservés. Les licences des dépendances restent
dans `vendor/`, avec leurs versions dans `go.mod` et `go.sum`.
