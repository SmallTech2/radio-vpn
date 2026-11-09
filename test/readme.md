# Tests automatisés

Ce dossier regroupe les tests Python utilisés pour vérifier le déploiement et les scripts :

- `test_deployment.py` : initialisation de SQLite et des configurations pour les réseaux `10.1`, `10.2` et `10.3`.
- `test_pki.py` : création, renouvellement et révocation des certificats, puis vérification de la CRL.
- `test_profile.py` : assemblage des profils clients avec leurs blocs PEM et `tls-crypt`.
- `test_ssh_hardening.py` : durcissement SSH et validation préalable de l'accès par clé, avec commandes système simulées.
- `test_ipv6.py` : désactivation IPv6 persistante et protection des sessions SSH, avec commandes réseau simulées.

Les tests travaillent dans des répertoires temporaires, sans accéder à un VPS.
Selon le test, ils nécessitent le binaire compilé, Bash, OpenSSL, Easy-RSA ou la commande OpenVPN.
GitHub Actions prépare les dépendances et exécute ces vérifications.

Ces fichiers ne sont pas nécessaires au fonctionnement du serveur installé.
