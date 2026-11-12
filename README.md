# Radio VPN — OpenVPN natif sur Debian 13

Radio VPN installe OpenVPN Community Edition et OpenVPN UI sur un VPS **Debian 13
AMD64**, avec Easy-RSA, systemd et nftables, sans Docker ni compilation sur le serveur.
Les équipements distants connectés **peuvent communiquer entre eux par leurs adresses
VPN privées fixes**, sous réserve de leurs pare-feu locaux. Ils conservent leur connexion
Internet habituelle.

Solution validée le 12 novembre 2026 sur Debian 13.7.

**Choisir votre procédure**

| Votre objectif | Projet | Procédure directe |
| --- | --- | --- |
| Installer un serveur VPN | [radio-vpn](https://github.com/SmallTech2/radio-vpn) | [Installer le serveur VPN](#installer-le-serveur-vpn) |
| Sauvegarder ce serveur | [radio-vpn-backup](https://github.com/SmallTech2/radio-vpn-backup) | [Installer la sauvegarde sur le VPS](https://github.com/SmallTech2/radio-vpn-backup/blob/main/docs/vps-installation.md) |
| Reconstruire et restaurer | [radio-vpn-restore](https://github.com/SmallTech2/radio-vpn-restore) | [Reconstruire et restaurer le serveur](https://github.com/SmallTech2/radio-vpn-restore/blob/main/docs/restoration.md) |

**Dans cette page**

- [Installer le serveur VPN](#installer-le-serveur-vpn)
- [Sauvegarder : installation VPS, puis choix de la collecte](#sauvegarder--installation-vps-puis-choix-de-la-collecte)
- [Restaurer et reprendre les sauvegardes](#restaurer-et-reprendre-les-sauvegardes)
- [Résultat de l’installation](#résultat-de-linstallation)
- [Version stable et démarrage rapide](#version-stable-et-démarrage-rapide)
- [Guides](#guides)
- [Licence et crédits](#licence-et-crédits)

## Installer le serveur VPN

Suivre les étapes ci-dessous dans l’ordre. Pour reconstruire un serveur en conservant
ses certificats, préparer également la [procédure de restauration](https://github.com/SmallTech2/radio-vpn-restore/blob/main/docs/restoration.md)
et reprendre **le même réseau VPN** que la sauvegarde.

### 1. Préparer le VPS et les informations

- **VPS vierge Debian 13 AMD64**, IPv4 publique et accès SSH IPv4 (`ssh -4`) avec droits sudo/root.
- Clé SSH publique **ED25519** du poste administrateur ; conserver la clé privée sur ce poste.
- Réseau VPN privé sans chevauchement avec les réseaux des clients et du VPS, de `/16` à `/29`.
- Nom du compte administrateur Linux, organisation, email PKI et mots de passe à définir.
- Autoriser chez l’hébergeur le port SSH utilisé (TCP 22 par défaut) et UDP 1194 ; ne pas ouvrir TCP 8080.

Le serveur prend la première adresse utilisable du réseau : `10.77.0.0/16` donne
`10.77.0.1/16`. Les [prérequis détaillés](docs/installation.md#prérequis) et les
[précautions IPv6](docs/security.md#désactivation-ipv6) expliquent ces choix.

### 2. Télécharger et lancer l’installateur

Sur le **VPS — compte disposant des droits sudo, session SSH interactive Bash** :

```bash
sudo apt update
sudo apt install -y curl
cd "$HOME"
curl --fail --location --proto '=https' --proto-redir '=https' \
  https://raw.githubusercontent.com/SmallTech2/radio-vpn/radio-v2.4/Radio/deploy-vps.sh \
  -o deploy-vps.sh
```

Attendre la réussite du téléchargement, puis lancer :

```bash
sudo bash deploy-vps.sh
```

En session root, omettre `sudo`. Conserver ce fichier jusqu’à la fin ; ne pas remplacer
le tag figé par `main`. Le script télécharge le paquet correspondant et vérifie ses
empreintes. Voir aussi le [téléchargement détaillé](docs/installation.md#télécharger-et-lancer-linstallateur-stable).

### 3. Reprendre après le redémarrage Debian

Le premier lancement prépare Debian avec `full-upgrade` et `autoremove --purge`, puis
redémarre le VPS après confirmation. Se reconnecter en IPv4, revenir dans le même
répertoire et relancer **le même fichier** :

```bash
cd "$HOME"
sudo bash deploy-vps.sh
```

La reprise est manuelle. Le script reconnaît la préparation déjà terminée ; voir le
[déroulement détaillé](docs/installation.md#préparation-debian-et-paramètres-interactifs).

### 4. Renseigner les paramètres et valider SSH

Confirmer l’IPv4 publique proposée, choisir le réseau VPN, le nom du compte Linux,
sa clé **publique**, l’organisation et l’email de la PKI. Après confirmation, le script
configure le clavier console et demande les mots de passe Linux et OpenVPN UI
(huit caractères minimum, saisie masquée et confirmation).

**Garder la session d’installation ouverte.** À la demande du script, ouvrir une nouvelle
connexion SSH IPv4 avec le compte créé et sa clé. Confirmer seulement lorsque cette
connexion fonctionne. Le script recherche la preuve d’authentification par clé avant
de désactiver les mots de passe SSH ; voir la [validation de l’accès par clé](docs/security.md#vérifier-laccès-par-clé).

Attendre la fin de l’installation. L’installateur refuse une installation ou une CA
existante : ne pas le relancer pour mettre à jour un serveur ou restaurer une sauvegarde.

### 5. Ouvrir l’interface et connecter les clients

Accéder à OpenVPN UI par [tunnel SSH, sans connexion VPN](docs/security.md#accès-à-openvpn-ui-par-tunnel-ssh),
ou par [l’adresse privée du serveur depuis le VPN](docs/security.md#accès-à-openvpn-ui-depuis-le-vpn).
Se connecter avec le compte Web `admin` et le mot de passe défini pendant l’installation.

Créer un certificat et une IP fixe par équipement, puis télécharger et installer son
profil `.ovpn` : [guide des clients et des communications entre clients](docs/administration.md#clients-ip-fixes-et-communication).
Deux clients connectés peuvent communiquer entre eux via leurs IP VPN ; leurs pare-feu
locaux doivent autoriser le trafic. Ils conservent leur connexion Internet habituelle.

## Sauvegarder : installation VPS, puis choix de la collecte

radio-vpn n’installe pas le système de sauvegarde. Installer d’abord
[radio-vpn-backup sur le VPS](https://github.com/SmallTech2/radio-vpn-backup/blob/main/docs/vps-installation.md),
avec la clé publique de la future collecte et une première archive contrôlée.
Choisir ensuite **une seule** des deux procédures :

| Méthode | Procédure dédiée |
| --- | --- |
| **Synology Active Backup for Business — principale** | [Configurer ABB, sa planification et sa rétention](https://github.com/SmallTech2/radio-vpn-backup/blob/main/docs/abb.md#5-configurer-abb) |
| **Collecteur Synology personnalisé — sans ABB** | [Préparer le compte NAS et planifier `nas-pull.sh` dans DSM](https://github.com/SmallTech2/radio-vpn-backup/blob/main/docs/installation.md) |

Le VPS prépare ses archives par cron ; le NAS les récupère par SSH. Les guides précisent
comment préparer la clé de collecte avant l’installation VPS. Le chiffrement est
[facultatif](https://github.com/SmallTech2/radio-vpn-backup/blob/main/docs/encryption.md) ;
les archives en clair contiennent des clés privées et doivent être protégées.

## Restaurer et reprendre les sauvegardes

Après perte du serveur, suivre la [reconstruction et restauration](https://github.com/SmallTech2/radio-vpn-restore/blob/main/docs/restoration.md) :
installer radio-vpn sur le nouveau VPS avec le même réseau VPN, récupérer l’archive du
NAS, effectuer `--check`, puis restaurer. La CA et les certificats clients sont conservés.

Réinstaller ensuite [radio-vpn-backup sur le VPS](https://github.com/SmallTech2/radio-vpn-backup/blob/main/docs/vps-installation.md)
et vérifier la collecte NAS. Le compte de collecte et son cron ne sont pas recréés par
la restauration. La [présentation de l’écosystème](docs/ecosystem.md) résume les rôles
et limites de compatibilité des trois projets.

## Résultat de l’installation

- Compte administrateur Linux choisi par l’utilisateur, sudo et SSH par clé ED25519.
- OpenVPN et OpenVPN UI gérés par systemd ; interface accessible par VPN ou tunnel SSH.
- PKI Easy-RSA unique, profils clients avec `tls-crypt`, IP fixes et renouvellement automatique de la CRL.
- **Communication entre clients VPN** : les équipements connectés peuvent se joindre par leurs adresses VPN privées grâce à `client-to-client`, si leurs pare-feu locaux autorisent le trafic souhaité.
- nftables : SSH et UDP 1194 accessibles publiquement ; TCP 8080 protégé.
- Désactivation persistante d’IPv6 après vérification de l’accès SSH en IPv4.
- Configuration du clavier console et [gestion automatique des logs](docs/maintenance.md#gestion-automatique-des-logs).

Le serveur utilise la première adresse du réseau privé choisi, de `/16` à `/29`.
Voir les [clients, IP fixes et communications](docs/administration.md#clients-ip-fixes-et-communication).
Le serveur n’est pas une passerelle Internet.
L’ajout d’un client dans l’UI ne redémarre pas OpenVPN. La révocation reste dans la PKI,
même lorsque le certificat est masqué dans la liste principale.

## Version stable et démarrage rapide

Version publiée : **[radio-v2.4](https://github.com/SmallTech2/radio-vpn/releases/tag/radio-v2.4)**,
avec paquet Linux AMD64, binaire, références des sources et empreintes SHA-256.
La [procédure d’installation ci-dessus](#installer-le-serveur-vpn) utilise cette référence figée.

## Guides

- [Installation détaillée](docs/installation.md) : prérequis, téléchargement, redémarrage et paramètres.
- [Administration](docs/administration.md) : accès à l’UI, clients, IP fixes et révocation.
- [Sécurité](docs/security.md) : SSH, console de secours, IPv6, nftables et accès Web.
- [Maintenance](docs/maintenance.md) : logs, CRL, services, diagnostic et mises à jour.
- [Écosystème](docs/ecosystem.md) : sauvegarde, collecte et restauration.
- [Index documentaire et références techniques](docs/README.md).

## Licence et crédits

Projet dérivé de [d3vilh/openvpn-ui](https://github.com/d3vilh/openvpn-ui), distribué
par Radio Bonheur sous [licence MIT](LICENSE). Les copyrights et attributions d’Adam
Wałach et de Mr. Philipp (d3vilh) sont conservés. Les licences des dépendances restent
dans `vendor/`, avec leurs versions dans `go.mod` et `go.sum`.
