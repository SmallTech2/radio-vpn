# Installation

[Accueil et installation](../README.md#installer-le-serveur-vpn) · [Tous les guides](README.md) · [Écosystème](ecosystem.md)

Les exemples de réseaux sont fictifs. Adaptez-les à votre installation.

**Dans cette page**

- [Prérequis](#prérequis)
- [Préparer le téléchargement](#préparer-le-téléchargement)
- [Télécharger et lancer l'installateur stable](#télécharger-et-lancer-linstallateur-stable)
- [Préparation Debian et paramètres interactifs](#préparation-debian-et-paramètres-interactifs)
- [Après l’installation](#après-linstallation)

## Prérequis

- VPS vierge Debian 13, architecture x86_64/AMD64, systemd et droits root/sudo.
- Session SSH interactive, commande `ip` (paquet `iproute2`) et `curl` pour le téléchargement.
- IPv4 publique fixe, accès HTTPS sortant aux miroirs Debian et à GitHub.
- Clé SSH **publique ED25519** du poste administrateur. Ne pas fournir la clé privée.
- Autoriser le port SSH utilisé (TCP 22 par défaut) et UDP 1194 dans le pare-feu de l'hébergeur.
  Ne pas ouvrir TCP 8080 sur Internet ; voir la [politique de filtrage](security.md#filtrage-entrant-avec-nftables).
- Choisir un sous-réseau privé qui ne chevauche pas les réseaux des clients et du VPS.

Pour ce déploiement IPv4 uniquement, utilisez une connexion SSH en
IPv4 (`ssh -4`) : IPv6 est désactivé sur le VPS après validation de l'accès par clé.
Voir le [fonctionnement et les précautions IPv6](security.md#désactivation-ipv6).

## Préparer le téléchargement

Connectez-vous en SSH au VPS Debian 13 vierge avec un compte disposant des droits sudo.
Installez l'outil de téléchargement :

```bash
sudo apt update
sudo apt install -y curl
```

Si vous êtes connecté directement en tant que `root`, exécutez les commandes de ce guide
sans le préfixe `sudo`.

## Télécharger et lancer l'installateur stable

Depuis un répertoire conservé après redémarrage, par exemple votre répertoire personnel :

```bash
cd ~
curl --fail --location --proto '=https' --proto-redir '=https' \
  "https://raw.githubusercontent.com/SmallTech2/radio-vpn/radio-v2.4/Radio/deploy-vps.sh" \
  -o deploy-vps.sh
```

Cette commande télécharge le script du tag figé correspondant à la Release stable
indiquée dans le [README principal](../README.md#version-stable-et-démarrage-rapide).
Le script télécharge ensuite le paquet de cette même Release et vérifie ses empreintes.
Ne remplacez pas le tag de l'URL par `main`. En cas d'échec du téléchargement, corrigez
l'erreur avant de poursuivre.

Après un téléchargement réussi, lancez :

```bash
sudo bash deploy-vps.sh
```

Conservez le fichier téléchargé pendant toute l'installation, y compris pour la relance
après redémarrage. Ne le téléchargez pas à nouveau entre ces deux étapes.

## Préparation Debian et paramètres interactifs

Au premier lancement, une confirmation précède `apt-get update`, `apt-get full-upgrade`
(en conservant les fichiers de configuration locaux) et `apt-get autoremove --purge`.
Le VPS redémarre ensuite. Après reconnexion SSH, relancer dans le même répertoire :

```bash
sudo bash deploy-vps.sh
```

L'état `/var/lib/radio-vpn/debian-upgrade-boot-id` est enregistré uniquement après
réussite des commandes APT. Le script vérifie le changement de démarrage et ne refait
pas la mise à niveau. Il ne reprend pas automatiquement et ne stocke aucun mot de passe
pour traverser le redémarrage.

Le script propose l'IPv4 publique détectée, modifiable, puis demande :

- Réseau VPN privé CIDR, par exemple `10.77.0.0/16` ou `192.168.42.0/24`.
- Nom du compte administrateur Linux à créer (`technicien` proposé par défaut).
- Clé publique SSH, organisation et email de la PKI ; remplacez les valeurs proposées par celles de votre organisation.
- Après confirmation et configuration du clavier console :
  mots de passe du compte Linux créé et de l'administrateur OpenVPN UI.

L'adresse email de la PKI est obligatoire et doit être renseignée par l'utilisateur.
Aucune adresse réelle de l'auteur du projet n'est proposée par défaut.

L'installateur installe `console-setup` et `keyboard-configuration`, puis applique la
disposition avec `setupcon --force`, y compris depuis une session SSH. Si
`/etc/default/keyboard` existe déjà et n'est pas vide, sa configuration est réutilisée
sans nouvel assistant. Sinon, l'assistant permet de choisir le français AZERTY ou
une autre disposition. Pour changer une configuration existante avant le déploiement,
utilisez `sudo dpkg-reconfigure keyboard-configuration` si le paquet est déjà installé.

Les deux mots de passe suivent la même règle : huit caractères minimum, aucune limite
maximale ajoutée par le script, espaces, accents et symboles acceptés sur une ligne,
saisie masquée et confirmation. Ils ne sont pas affichés dans le récapitulatif.
Une seconde confirmation précède l'installation VPN.
L'installateur impose la validation d'une nouvelle connexion par clé dans une seconde
session SSH avant de poursuivre. Gardez la session d'installation ouverte et suivez
les instructions affichées. Le parcours demande
simplement de confirmer que la nouvelle connexion fonctionne ; sa preuve par clé
est recherchée automatiquement dans le journal SSH. Vérifiez l'accès par clé et le durcissement
[selon le guide de sécurité](security.md#vérifier-laccès-par-clé).

Pour l'accès local et le clavier de secours de l'hébergeur, consultez la
[section console VNC](security.md#console-vnc-ou-console-de-secours).

Les réseaux RFC1918 sont acceptés de `/16` à `/29`, limites de la directive serveur OpenVPN
avec `tun`. Une adresse d'hôte à la place de l'adresse réseau et les chevauchements
avec les routes présentes sur le VPS sont refusés. Les conflits avec les futurs réseaux
clients restent à vérifier par l'administrateur. Le serveur utilise toujours **réseau + 1** :
`10.77.0.0/16` donne `10.77.0.1/16`, `192.168.42.0/24` donne `192.168.42.1/24`.

Le script refuse de remplacer une installation ou une CA existante. Il télécharge le
paquet de la Release sélectionnée, vérifie son SHA-256 puis les empreintes internes et
utilise les sources de déploiement du commit inscrit dans ce paquet.
Conservez la référence figée fournie dans le README principal, sans la remplacer par une
branche de développement ou par un lien mouvant de type « latest ».

## Après l’installation

1. [Accéder à OpenVPN UI](administration.md#accès-à-openvpn-ui), puis [créer les clients à IP fixe et vérifier leur communication](administration.md#clients-ip-fixes-et-communication).
2. [Installer radio-vpn-backup sur le VPS](https://github.com/SmallTech2/radio-vpn-backup/blob/main/docs/vps-installation.md), puis choisir la collecte [ABB](https://github.com/SmallTech2/radio-vpn-backup/blob/main/docs/abb.md#5-configurer-abb) ou [personnalisée](https://github.com/SmallTech2/radio-vpn-backup/blob/main/docs/installation.md).
3. Suivre la [maintenance](maintenance.md) et les [contrôles de sécurité](security.md).

Pour une reconstruction avec sauvegarde, poursuivre avec la [restauration](https://github.com/SmallTech2/radio-vpn-restore/blob/main/docs/restoration.md), avant de créer de nouveaux clients.
