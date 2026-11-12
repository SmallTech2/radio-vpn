# Écosystème Radio VPN

Trois dépôts distincts assurent le cycle de vie du serveur :

**Installation avec radio-vpn → sauvegarde avec radio-vpn-backup → reconstruction avec
radio-vpn → restauration avec radio-vpn-restore.**

Solution validée le 12 novembre 2026 sur Debian 13.7.

## Choisir la bonne procédure

| Besoin | Projet et guide |
| --- | --- |
| Installer un serveur Debian 13 AMD64 vierge | [radio-vpn — installation](installation.md) |
| Gérer les clients, les IP fixes et les révocations | [radio-vpn — administration](administration.md) |
| Préparer les archives et les collecter avec Synology ABB | [radio-vpn-backup — ABB](https://github.com/SmallTech2/radio-vpn-backup/blob/main/docs/abb.md) |
| Collecter sans ABB | [radio-vpn-backup — collecteur personnalisé](https://github.com/SmallTech2/radio-vpn-backup/blob/main/docs/installation.md) |
| Reconstruire après perte du VPS en conservant les certificats | [radio-vpn-restore — restauration](https://github.com/SmallTech2/radio-vpn-restore/blob/main/docs/restoration.md) |

## Rôles et dépendances

**radio-vpn** fournit le socle : services, arborescences, PKI, base OpenVPN UI et
protection réseau. Une installation vierge crée une PKI initiale ; elle ne récupère
pas les identités d’un ancien serveur.

**radio-vpn-backup** prépare sur ce socle une archive confidentielle cohérente avec
la PKI, la CRL, les profils, les adresses fixes et la base UI. Le VPS prépare l’archive
par cron ; le NAS la récupère en PULL par SSH. ABB ou le collecteur personnalisé gère
la collecte et la conservation sur le NAS. Le dépôt public n’est pas la sauvegarde du VPS.

**radio-vpn-restore** utilise une archive de radio-vpn-backup sur un serveur déjà
reconstruit avec radio-vpn et le **même réseau VPN**. Il remplace la PKI provisoire et
les données applicatives, sans recréer la CA ni les certificats sauvegardés. Le compte
Linux, ses accès SSH et les réglages réseau de destination sont conservés.

## Périmètre de compatibilité

La chaîne est conçue pour l’association de ces trois projets sous Debian 13 AMD64.
Un serveur OpenVPN installé manuellement ou autrement n’est pas garanti compatible
avec radio-vpn-backup. Une sauvegarde d’un autre système, ou une destination préparée
autrement qu’avec radio-vpn, n’est pas garantie compatible avec radio-vpn-restore.
L’utilisation d’une partie de l’écosystème ne bénéficie pas nécessairement du même
périmètre de compatibilité. Une adaptation extérieure demeure possible mais demande
sa propre analyse.

La sauvegarde et la restauration contrôlent les composants et configurations présents,
pas une égalité de numéros de version. Le lecteur de restauration attend le **format
interne 1** de radio-vpn-backup, les fichiers essentiels et une configuration compatible.
`--check` effectue ce contrôle sans remplacer la destination ni arrêter ses services.
Un numéro de version accepté n’autorise pas à contourner une erreur de PKI ou de schéma.

## Conservation des données

Une archive non chiffrée contient notamment la clé privée de la CA : conserver les
archives et leurs empreintes dans un stockage protégé, accessible sans le VPN à reconstruire.
Le chiffrement age est facultatif ; sa clé privée doit être conservée hors du VPS source.
L’IP publique et le compte Linux peuvent différer à la restauration, mais les copies de
profils déjà distribuées nécessitent une mise à jour de `remote` si l’IP publique change.
