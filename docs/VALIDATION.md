# Suivi technique : validations et limites

Document de maintenance de l’écosystème, distinct des procédures utilisateur. Les
résultats réels ci-dessous proviennent du compte rendu de l’administrateur du
12 novembre 2026 ; ils ne sont pas étendus à des scénarios non confirmés.

## Reconstruction et restauration réalisées

Environnement déclaré : **VPS Infomaniak, Debian 13.7 AMD64**, sauvegarde non chiffrée
créée avec radio-vpn-backup sur une installation radio-v2.1. La sauvegarde utilisée
date du 11 novembre 2026. Le numéro exact du déploiement de destination n’a pas été
fourni dans ce compte rendu ; il n’est pas déduit du seul succès de la restauration.

Les opérations suivantes ont été confirmées :

1. Réinstallation du VPS sous Debian 13 et installation du serveur avec radio-vpn.
2. Utilisation d’une sauvegarde réelle produite par radio-vpn-backup.
3. Récupération depuis le NAS Synology et extraction de `backup.tar.gz` et `SHA256SUMS`.
4. Contrôle de l’archive avec `restore.sh --check`.
5. Restauration complète avec radio-vpn-restore.
6. Démarrage d’OpenVPN et d’OpenVPN UI.
7. Reconnexion d’un ancien client VPN avec son certificat existant.

Une collecte réelle ABB en mode **rsync module via SSH**, avec le compte
`radio-vpn-backup`, a également été confirmée pendant la mise en place de la sauvegarde.
Ces constats ne prouvent pas à eux seuls la rétention sur plusieurs semaines, le
comportement après un changement d’IP ou le refus réel d’un certificat révoqué.

## Vérifications automatisées réalisées

Les références ci-dessous sont des exécutions GitHub Actions réussies, sur des
runners et données temporaires, indépendantes de la recette Infomaniak.

| Projet | Contrôles | Référence |
| --- | --- | --- |
| radio-vpn | Syntaxe Bash, tests et vet Go, compilation Linux AMD64, initialisation UI/SQLite, parcours SSH et IPv6 simulés, PKI Easy-RSA, profils, CRL et paquet SHA-256 | [Exécution du socle](https://github.com/SmallTech2/radio-vpn/actions/runs/42621307563) ; [publication du paquet](https://github.com/SmallTech2/radio-vpn/actions/runs/42622214190) |
| radio-vpn-backup | Archives standard/age, intégrité, PKI/SQLite/CCD, fichiers facultatifs, rétention, saisie manuelle et cron sans terminal, génération de l’horaire, transferts SSH/rsync réels sur loopback et refus d’écriture/hors export | [Exécution backup](https://github.com/SmallTech2/radio-vpn-backup/actions/runs/42861569933) |
| radio-vpn-restore | Formats standard/age, bonne/mauvaise clé, extraction bornée, source simulée v2.1 vers destination v2.4, préservation PKI et configurations de destination, retour arrière, mode `--check`, contrôle SSH avec sortie volumineuse, configurations OpenVPN générées et refus ciblés | [Exécution restore](https://github.com/SmallTech2/radio-vpn-restore/actions/runs/43195125079) |

Les tests de restauration comparent les clés, certificats, métadonnées et IP fixes ;
ils couvrent les erreurs de schéma, de révocation, de masque/réseau et les doublons de
directives. Les essais crypto ne sont pas des restaurations chiffrées réelles sur VPS.
Les tests de rsync ne reproduisent pas toute l’interface, les ACL et la planification DSM.
Les commandes de contrôle documentaire ne constituent pas une nouvelle recette fonctionnelle.

## Scénarios réels non confirmés

- Sauvegarde age, récupération de sa clé et restauration complète après déchiffrement.
- Restauration vers une autre IPv4 publique, puis mise à jour des profils distribués.
- Connexion effectivement refusée à un certificat déjà révoqué après restauration.
- Grand nombre de clients, volume important, durée d’interruption et capacité disque correspondante.
- Relevé comparatif explicite des empreintes CA, séries et IP fixes sur le serveur réel.
- Contrôles complets après redémarrage du serveur restauré.
- Retour arrière sur panne réelle, coupure électrique, SIGKILL ou défaillance de disque.
- Conservation ABB sur plusieurs semaines, notifications/ACL DSM et reprise après interruption NAS.
- Autres hébergeurs, architectures ou installations OpenVPN extérieures à ces projets.

L’absence de confirmation n’est ni un échec constaté ni une impossibilité technique.
Un scénario supplémentaire ne rejoint la liste des constats qu’après un résultat explicite.

## Contrat technique actuel

- Debian 13 AMD64 ; socle et arborescences de radio-vpn requis sur la destination.
- Réseau privé RFC1918 de `/16` à `/29` ; même réseau sur la source et la destination
  pour conserver le pare-feu. Serveur sur la première adresse utilisable, clients en CCD.
- Version/commits conservés dans les métadonnées ; aucune égalité stricte de Release
  n’est imposée par backup ou restore. La compatibilité de versions non examinées ne
  découle pas de la seule présence d’un nom de version accepté.
- Format d’archive **1** : `manifest.json`, `INVENTORY.txt`, `payload/`, modes et
  propriétaires numériques, empreintes internes et chemins/lignes de configuration contrôlés.
- `crlnumber` est facultatif. La CA, ses clés, `index.txt`, `serial` et `crl.pem` restent
  requis, ainsi que le runtime UI, SQLite et les composants de renouvellement CRL.
- Les références SSH, nftables et IPv6 archivées ne sont pas réinjectées. Les fichiers
  de logs présents sont restaurés ; s’ils sont absents, ceux de destination sont conservés.
- L’outil de restauration remplace aussi le binaire et les ressources UI par ceux de
  l’archive : restaurer ne constitue pas une mise à jour vers le code applicatif du nouveau socle.

## Limites et points de maintenance

**SHA-256 externe.** `restore.sh` ne lit ni `SHA256SUMS` ni un fichier `.sha256` pour
l’archive reçue. Le guide demande explicitement `sha256sum -c` avant son lancement.
Le script contrôle ensuite gzip, le manifeste et les empreintes internes. La copie
`archive.tar.gz.sha256` est une convention de procédure/collecteur, pas un fichier
exigé automatiquement par le programme. SHA-256 ne prouve pas l’identité de l’auteur.

**Cohérence.** Backup suspend l’UI et le timer CRL, attend une opération CRL et refuse
une opération Easy-RSA déjà active. Il n’existe pas de transaction unique PKI/SQLite/CCD
ni de verrou universel contre une administration manuelle concurrente.

**Remplacement et secours.** `--check` travaille dans `/tmp` et ne démarre pas les
services restaurés. La restauration les arrête après confirmation, conserve un secours
local et tente un retour arrière sur erreur interceptable. Une panne brutale n’est pas
récupérable par un simple trap. Les secours locaux ne sont pas purgés automatiquement.

**Rétention et alertes.** Le VPS conserve `KEEP_VPS` points (3 par défaut, de 2 à 30),
même si le NAS ne collecte plus. ABB assure sa propre rétention ; le collecteur
personnalisé applique `DAILY`/`WEEKLY`. Le cron VPS n’a pas de notification mail intégrée.

**Réseau et SSH.** La chaîne nftables `forward` a une politique `accept` ; le déploiement
ne force pas `net.ipv4.ip_forward=0`. Ce service n’est pas une passerelle universelle.
Les règles SSH personnalisées et les réseaux extérieurs au contrat demandent une analyse
spécifique. La désactivation IPv6 concerne le VPS, pas les postes clients.

Les procédures utilisateur sont dans [l’index](README.md) et dans les guides de
[backup](https://github.com/SmallTech2/radio-vpn-backup) et
[restore](https://github.com/SmallTech2/radio-vpn-restore). Les scénarios non confirmés
ci-dessus constituent la liste de suivi ; ils ne sont pas des étapes supplémentaires
de la procédure nominale.
