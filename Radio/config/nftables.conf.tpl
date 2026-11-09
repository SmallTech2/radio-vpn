#!/usr/sbin/nft -f

flush ruleset

table inet filter {
    chain input {
        type filter hook input priority 0; policy drop;

        iif "lo" accept
        ct state established,related accept
        ct state invalid drop

        tcp dport { @SSH_PORTS@ } accept
        udp dport 1194 accept

        iifname "tun0" tcp dport 8080 accept
        ip protocol icmp accept
        meta l4proto ipv6-icmp accept
    }

    chain forward {
        type filter hook forward priority 0; policy accept;
    }

    chain output {
        type filter hook output priority 0; policy accept;
    }
}
