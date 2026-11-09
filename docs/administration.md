# Administration

Ce guide décrit l'utilisation d'un serveur installé depuis la référence publiée indiquée
dans le [README principal](../README.md#version-stable-et-démarrage-rapide). Les exemples de réseaux sont fictifs.
Remplacez `UTILISATEUR_LINUX` par le compte créé par l'installateur.

## Accès à OpenVPN UI

Connectez-vous avec le compte Web `admin` et le mot de passe saisi à l'installation.
Le [guide de sécurité](security.md) centralise les deux méthodes d'accès :

- [Tunnel SSH, sans connexion OpenVPN](security.md#accès-à-openvpn-ui-par-tunnel-ssh).
- [Adresse privée du serveur, avec une connexion VPN active](security.md#accès-à-openvpn-ui-depuis-le-vpn).

Le même guide décrit le filtrage nftables qui protège l'interface.

## Clients, IP fixes et communication

Dans la page **Certificates** de l'UI, créer un certificat par appareil avec un nom unique
et une IPv4 fixe libre du réseau VPN. Ne pas utiliser l'adresse réseau, celle du serveur,
la diffusion ou une IP déjà attribuée. Exemple fictif pour `10.77.0.0/16` : serveur
`10.77.0.1`, clients `10.77.0.10` et `10.77.0.11`.

Télécharger chaque profil `.ovpn` dans l'UI et le transmettre de façon confidentielle.
Il contient le certificat client, sa clé privée, la CA et `tls-crypt`.
Les fichiers CCD de `/etc/openvpn/staticclients` portent les IP fixes avec le bon masque.
`nopool` et `ccd-exclusive` interdisent les attributions dynamiques ; il n'y a donc pas
`ifconfig-pool-persist`. `client-to-client` permet la communication entre clients.
Aucun `redirect-gateway` n'est poussé : les clients conservent leur Internet habituel.

Le pare-feu local de chaque client doit autoriser le trafic VPN souhaité. Vérifiez la connexion
simultanée de deux clients, leur interconnexion et leur reconnexion après redémarrage.

## Révocation, suppression et renouvellement des clients

1. Dans **Certificates**, repérez le nom et le numéro de série du certificat à révoquer,
   puis utilisez **Revoke**. L'opération conserve l'entrée révoquée de l'index CA et régénère la CRL.
2. Déconnectez l'appareil et vérifiez qu'une nouvelle connexion avec son ancien profil est
   refusée. Une connexion déjà établie n'est pas nécessairement interrompue immédiatement.
3. Utilisez ensuite **Delete files** si vous souhaitez nettoyer les fichiers du client.
   Cette suppression ne remplace pas la révocation et conserve son historique dans la CA.

Pour renouveler un certificat, utilisez l'action de renouvellement dans l'interface,
puis téléchargez et distribuez le nouveau profil `.ovpn` à l'appareil concerné.


Voir aussi le [renouvellement de la CRL et le diagnostic](maintenance.md)
et la [vérification de l'accès SSH par clé](security.md#vérifier-laccès-par-clé).
