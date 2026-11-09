# Scripts d'administration natifs

Ces scripts sont installés dans `/opt/scripts` pour le déploiement et les opérations
d'administration d'OpenVPN UI.
Le [guide utilisateur](../../docs/README.md) décrit leur utilisation depuis l'interface.
Les chemins de la PKI et d'OpenVPN sont lus dans
`/opt/openvpn-ui-runtime/conf/app.conf`. Certains scripts acceptent `OPENVPN_UI_CONFIG`
pour sélectionner un autre fichier de configuration.

| Script | Responsabilité |
| --- | --- |
| `generate_ca_and_server_certs.sh` | Initialiser une PKI unique et les certificats serveur, sans remplacer une CA existante |
| `genclient.sh` / `write-client-profile.sh` | Générer le certificat puis assembler le profil complet avec ses blocs PEM et `tls-crypt` |
| `renew.sh` | Renouveler le certificat et régénérer le profil sans purger l'historique CA |
| `revoke.sh` | Révoquer le numéro de série visé, conserver l'entrée dans l'index et régénérer la CRL |
| `rmcert.sh` | Nettoyer les fichiers d'un certificat révoqué, sans supprimer l'historique des révocations |
| `restart.sh` | Redémarrer les services natifs via systemd |
| `secure-ssh.sh` | Désactiver les mots de passe SSH après preuve d'une connexion avec la clé fournie |
| `oath.sh` | Exemple de vérification OTP, non activé par le déploiement standard |
| `remove.sh` | Suppressions globales explicitement demandées dans l'interface ; opérations destructives |

Le code applicatif valide l'IP fixe et crée le fichier CCD en complément de l'appel
au générateur de certificat. Un appel isolé à `genclient.sh`
ne remplace donc pas le parcours complet de création d'un client dans l'interface.

Conservez la PKI et les profils hors du dépôt public. Ne purgez pas l'index de la CA
pour supprimer un client : les entrées révoquées restent nécessaires aux futures CRL.
La planification systemd de la CRL est créée par `../deploy-vps.sh`.

Le helper `secure-ssh.sh` détermine le compte via `SUDO_USER` et son répertoire
via `getent passwd` ; aucun nom de compte n'est fixé dans ce script.
L'installateur récupère le helper depuis le commit de déploiement inscrit dans le paquet
puis installe `/usr/local/bin/radio-secure-ssh`
et la copie de `/opt/scripts`.
La référence du helper figure dans `SSH_HARDENING_COMMIT` et dans l'état de déploiement.

La validation SSH est obligatoire avant la suite de l'installation : preuve dans le journal
de la nouvelle connexion par clé du compte choisi, contrôle `sshd -t` et `sshd -T` global
et contextualisé, puis rechargement. Les mots de passe et le clavier interactif sont désactivés,
et `AuthenticationMethods publickey` impose la clé seule. Un échec après modification provoque
la restauration du fichier précédent. Le helper ne redémarre pas le service SSH.

L'installateur mémorise un curseur du journal avant
de demander une nouvelle connexion. Après confirmation, il appelle le helper avec
`--after-cursor CURSOR ADRESSE_LOCALE PORT_SSH` et `SUDO_USER` égal au compte choisi.
Le helper recherche automatiquement l'authentification par clé après ce curseur ;
aucune recopie de `SSH_CONNECTION` n'est demandée. Un appel manuel depuis
une session administrateur avec `sudo radio-secure-ssh "$SSH_CONNECTION"` reste accepté.
Voir le [guide de sécurité](../../docs/security.md#vérifier-laccès-par-clé).
