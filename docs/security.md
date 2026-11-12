# Sécurité

Utilisez la référence publiée indiquée dans le [README principal](../README.md#version-stable-et-démarrage-rapide).
## Compte administrateur et SSH

Utilisez le compte Linux choisi pendant l'installation et indiqué dans son récapitulatif.
Conservez ce nom pour les commandes SSH et sudo.
Le compte dispose d'un répertoire personnel, de Bash, de sudo avec mot de passe
et de la clé publique ED25519 fournie. L’administration SSH s’effectue avec cette clé.
Ne copiez jamais votre clé privée sur le serveur.

## Vérifier l'accès par clé

Gardez la session d'installation ouverte. Depuis un autre terminal de votre poste,
ouvrez une nouvelle connexion avec le compte créé et la clé fournie :

```bash
ssh -4 -o ControlMaster=no -o ControlPath=none -o PreferredAuthentications=publickey \
  -o PasswordAuthentication=no -o KbdInteractiveAuthentication=no \
  UTILISATEUR_LINUX@IP_PUBLIQUE_DU_SERVEUR
```

Ajoutez `-p PORT_SSH` si nécessaire et `-i CHEMIN_CLE_PRIVEE` si la clé n'est pas sélectionnée
automatiquement. Une demande de phrase secrète locale pour ouvrir la clé privée ne constitue
pas une authentification SSH par mot de passe.

Ne désactivez jamais les mots de passe avant la réussite de cette nouvelle connexion par clé.
Après validation de cette preuve, le durcissement SSH désactive l’authentification par mot
de passe et par clavier interactif, tout en conservant l’accès par clé ED25519.
Gardez cette nouvelle session ouverte, revenez dans l'installateur et répondez `oui`. Aucune valeur de
`SSH_CONNECTION` n'est à recopier. L'installateur repère d'abord sa position dans le
journal SSH, puis recherche une authentification `Accepted publickey` postérieure à
ce repère, pour le compte choisi et l'empreinte de la clé ED25519 installée.
La confirmation seule ne suffit pas. Sans preuve correspondante, le durcissement
n'est pas appliqué et l'utilisateur peut ouvrir une nouvelle connexion puis réessayer.
Les contrôles effectifs et la restauration après échec restent obligatoires.

Cette détection dépend du journal systemd du service SSH, de sa disponibilité et du
format des messages OpenSSH. Si le journal est inaccessible, incomplet ou ne contient
pas la preuve attendue, la validation échoue sans désactiver les accès existants.
Une connexion multiplexée ne crée pas nécessairement une nouvelle authentification :
utilisez la commande ci-dessus. Le journal prouve une authentification réussie, pas
que la session restera ouverte ; conservez-la et vérifiez encore l’accès après durcissement.
L'adresse locale et le port utilisés pour `sshd -T` sont ceux de la session d'installation
(à défaut, l'adresse publique et le port SSH effectif). Ce parcours suppose que la
nouvelle connexion utilise ce même point d'entrée SSH.

## Vérifier le durcissement effectif

Ne vous fiez pas uniquement au contenu d'un fichier : les inclusions et les règles
`Match` peuvent changer la configuration effective. Dans la session SSH concernée :

```bash
sudo /usr/sbin/sshd -t
read -r CLIENT_IP CLIENT_PORT SERVER_IP SERVER_PORT <<< "$SSH_CONNECTION"
sudo /usr/sbin/sshd -T -C "user=$(id -un),addr=$CLIENT_IP,host=$CLIENT_IP,laddr=$SERVER_IP,lport=$SERVER_PORT" \
  | grep -E '^(pubkeyauthentication|passwordauthentication|kbdinteractiveauthentication|authenticationmethods) '
```

Le contrôle doit confirmer au minimum `pubkeyauthentication yes`,
`passwordauthentication no` et `kbdinteractiveauthentication no`.
Lorsque `AuthenticationMethods publickey` est configuré, vérifiez également
`authenticationmethods publickey`.

L'installateur fournit `/usr/local/bin/radio-secure-ssh`. Le helper vérifie la preuve
d'accès par clé, contrôle les valeurs effectives et restaure la configuration
précédente en cas d'échec. Un contrôle en échec ne constitue pas un durcissement réussi.

Gardez les sessions existantes ouvertes et vérifiez une nouvelle connexion par clé
après tout rechargement de SSH avant de les fermer.

## Console VNC ou console de secours

La console proposée par l'hébergeur permet d'intervenir lorsque SSH ou OpenVPN sont
inaccessibles. Son accès et son comportement dépendent aussi de l'hébergeur.
Le durcissement SSH par clé ne désactive pas l'authentification locale par mot de passe :
conservez donc un mot de passe Linux fonctionnel pour le compte administrateur.

La disposition du clavier de cette console peut différer de celle de votre PC.
Les utilisateurs français peuvent sélectionner le français AZERTY, sans que ce choix
soit imposé aux autres utilisateurs. La disposition doit aussi être effectivement
appliquée à la console Debian ; le seul contenu de `/etc/default/keyboard` ne suffit
pas à le confirmer. Vérifiez la saisie dans la console de secours.

Pour dépanner manuellement, installez les paquets nécessaires, choisissez la disposition,
puis appliquez-la :

```bash
sudo apt install -y console-setup keyboard-configuration
sudo dpkg-reconfigure keyboard-configuration
sudo setupcon --force
```

Ces commandes concernent le clavier de la console Debian, pas celui de votre terminal SSH.

## Désactivation IPv6

Le déploiement cible IPv4. L'installateur désactive IPv6 sur le VPS après la validation
d'une nouvelle connexion SSH par clé en IPv4 (`ssh -4`).

Le fichier `/etc/sysctl.d/99-radio-disable-ipv6.conf` rend la désactivation persistante :

```ini
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
```

L'installateur applique uniquement ce fichier avec `sysctl -p`, puis vérifie les valeurs
pour toutes les interfaces présentes, y compris la boucle locale. Les nouvelles interfaces
héritent du réglage par défaut. Si IPv6 est déjà indisponible dans le noyau, il conserve
le fichier sans tenter d'appliquer des paramètres inexistants.

Ne lancez pas ce déploiement depuis SSH en IPv6. L'installateur refuse une session
identifiée comme IPv6 et vérifie aussi l'absence de sessions TCP IPv6 actives de `sshd`
avant la désactivation, même si `sudo` a retiré les variables SSH. Reconnectez-vous en
IPv4 et fermez les autres sessions SSH IPv6 si ce contrôle bloque la suite.
La console de secours de l'hébergeur reste un moyen d'accès local.

Cette désactivation concerne le VPS uniquement : elle ne désactive pas IPv6 sur les
postes clients et ne transforme pas le VPN en passerelle pour leur trafic Internet.
Le routage IPv4 et les règles nftables ne sont pas modifiés par cette étape.

## Filtrage entrant avec nftables

Le filtrage entrant des services du VPS utilise une politique de refus par défaut
(`input`, `policy drop`). Dans la configuration standard avec SSH sur son port habituel,
**seuls deux ports acceptent de nouvelles connexions depuis Internet** :

| Port entrant public | Usage |
| --- | --- |
| **TCP 22** | Administration SSH par clé ED25519 |
| **UDP 1194** | Connexions des clients OpenVPN |

Les autres ports entrants depuis Internet sont bloqués par défaut. Les exceptions
nécessaires au fonctionnement réseau comprennent ICMP et ICMPv6. Le pare-feu accepte
également le trafic local de loopback et les paquets des connexions déjà établies ou associées.

Si SSH est volontairement configuré sur un autre port, l'installateur conserve les ports
SSH effectifs pour éviter une perte d'accès ; il ne les remplace pas arbitrairement par 22.
Le pare-feu de l'hébergeur doit autoriser le port SSH réellement utilisé et UDP 1194.

OpenVPN UI écoute sur **TCP 8080**, mais ce port **n'est pas directement accessible
depuis Internet**. Son accès est permis localement sur le VPS ou depuis l'interface VPN
`tun0`. Il n'est pas nécessaire d'ouvrir 8080, ni le port local du tunnel, dans le pare-feu public.
Le management OpenVPN reste local sur `127.0.0.1:2080`.

Cette politique décrit l'accès aux services du VPS, dans la chaîne `input`.

## Routage du noyau et communication interclients

La chaîne nftables `forward` utilise une politique `accept`. L'installateur ne modifie
pas le routage IPv4 du noyau. Pour un serveur sans rôle de routeur entre interfaces,
vérifiez que `net.ipv4.ip_forward` vaut `0` :

```bash
sysctl net.ipv4.ip_forward
```

IPv6 est désactivé par les paramètres `disable_ipv6` décrits ci-dessus.
La communication entre clients VPN utilise la directive OpenVPN `client-to-client` ;
elle ne nécessite pas d'activer le routage IP du noyau pour cet usage.

Les règles sont conservées pour cet usage précis : elles ne constituent pas un pare-feu
universel pour tous les usages. L'ajout d'un rôle de routeur, d'un accès à d'autres réseaux
ou l'activation du forwarding impose une analyse distincte du routage et du filtrage.

## Accès à OpenVPN UI par tunnel SSH

Cette méthode ne nécessite **aucune connexion OpenVPN** : seule une connexion SSH
à l'IPv4 publique du VPS est nécessaire. Depuis votre poste, remplacez le chemin de clé,
le nom d'utilisateur et l'adresse publique dans cet exemple générique :

```bash
ssh -N -T -i "/chemin/vers/cle_privee" \
  -L 127.0.0.1:8083:127.0.0.1:8080 \
  utilisateur@IP_PUBLIQUE_DU_VPS
```

Ajoutez `-p PORT_SSH` si le serveur n'utilise pas le port SSH 22. Une fois le tunnel établi,
ouvrez [http://127.0.0.1:8083/](http://127.0.0.1:8083/) dans le navigateur de ce même poste.
Le port **8083 est local au poste** ; SSH transmet la connexion vers `127.0.0.1:8080`
sur le VPS. Il n'expose pas l'interface Web sur l'adresse publique du serveur.

**Le tunnel SSH doit rester actif pendant toute la durée de l'administration.**
Cette méthode fonctionne même si le service OpenVPN est arrêté, à condition que le VPS,
le service SSH et OpenVPN UI fonctionnent et que la protection nftables soit conservée.
L'interface dépend de nftables, pas du service OpenVPN.

## Accès à OpenVPN UI depuis le VPN

Avec une **connexion VPN active**, un client peut accéder directement à l'interface Web
à l'adresse VPN privée du serveur, sur TCP 8080.

Exemple générique pour le réseau `10.3.0.0/16`, dont la première adresse utilisable est
celle du serveur : [http://10.3.0.1:8080/](http://10.3.0.1:8080/).
Adaptez l'adresse au réseau effectivement choisi lors du déploiement.

Cet accès nécessite que le service OpenVPN fonctionne et que le client soit connecté au VPN.
Sans VPN actif, utilisez le tunnel SSH décrit ci-dessus.

## Protection pendant l'installation

L'interface dépend de `nftables.service`. Ne la démarrez pas sans la protection du pare-feu.
À l'installation, un retour arrière systemd est armé pour trois minutes, avec retour
immédiat sur erreur. Il restaure les règles précédentes et arrête VPN/UI. Il n'est annulé
qu'après les contrôles locaux des services, de l'adresse CIDR de `tun0`, de l'UDP et du HTTP.
Vérifiez une nouvelle connexion SSH depuis votre poste avant de fermer la session
utilisée pour l'installation ou une intervention réseau.
