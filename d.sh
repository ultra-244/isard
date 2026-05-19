#!/bin/bash

# --- VARIABLES ---
REALM="dom-samba-bfp.lan"
DOMAIN="DOM-SAMBA-BFP"
PASS="P@ssword2026!"
IP="192.168.2.100"
HOSTNAME="sambaserver-bfp"

echo "=== 1. NETEJANT TOT EL SISTEMA ==="
systemctl stop samba-ad-dc smbd nmbd winbind systemd-resolved 2>/dev/null
apt-get purge -y samba smbclient winbind krb5-user krb5-config samba-common-bin 2>/dev/null
rm -rf /etc/samba /var/lib/samba /var/cache/samba /etc/krb5.conf

echo "=== 2. CONFIGURANT XARXA I HOSTNAME ==="
hostnamectl set-hostname $HOSTNAME
echo "$HOSTNAME" > /etc/hostname

cat <<NetEOF > /etc/network/interfaces
auto lo
iface lo inet loopback
auto enp2s0
iface enp2s0 inet static
    address $IP
    netmask 255.255.255.0
    gateway 192.168.2.1
NetEOF
ifdown enp2s0 && ifup enp2s0

echo "=== 3. PREPARANT FITXERS DE SISTEMA ==="
cat <<HostsEOF > /etc/hosts
127.0.0.1 localhost
$IP $HOSTNAME.$REALM $HOSTNAME
HostsEOF

echo "nameserver 127.0.0.1" > /etc/resolv.conf
chattr +i /etc/resolv.conf

echo "=== 4. INSTAL·LANT PAQUETS ==="
apt-get update && apt-get install -y samba smbclient winbind krb5-user krb5-config

echo "=== 5. PROVISIÓ DEL DOMINI ==="
rm -f /etc/samba/smb.conf
samba-tool domain provision --use-rfc2307 --realm="$REALM" --domain="$DOMAIN" --adminpass="$PASS" --server-role=dc --dns-backend=SAMBA_INTERNAL --host-ip="$IP"

cp /var/lib/samba/private/krb5.conf /etc/krb5.conf

echo "=== 6. ARRENCANT SAMBA AD DC ==="
systemctl unmask samba-ad-dc
systemctl enable samba-ad-dc
systemctl restart samba-ad-dc

echo "Esperant estabilització..."
sleep 10
samba_dnsupdate --verbose

echo "=== ✅ PROCÉS FINALITZAT ==="
echo "Comprova l'estat amb: systemctl status samba-ad-dc"
