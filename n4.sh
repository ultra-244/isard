cat << 'EOF' > n.sh
#!/bin/bash

if [ "$EUID" -ne 0 ]; then
  echo "Aquest script s'ha d'executar amb sudo: sudo ./n.sh"
  exit
fi

echo "=================================================="
echo "⚙️  CONFIGURACIÓ DE XARXA I HOSTNAME"
echo "=================================================="

REALM="dom-samba-bfp.lan"
DOMAIN="DOM-SAMBA-BFP"
PASS="P@ssword2026!"
IP="192.168.2.100"
HOSTNAME="sambaserver-bfp"

# 1. Forçar Hostname correcte
hostnamectl set-hostname $HOSTNAME
echo "$HOSTNAME" > /etc/hostname

# 2. Configurar la targeta enp2s0 amb IP estàtica fixa
cat << NetEOF > /etc/network/interfaces
source /etc/network/interfaces.d/*

auto lo
iface lo inet loopback

auto enp2s0
iface enp2s0 inet static
    address $IP
    netmask 255.255.255.0
    network 192.168.2.0
    broadcast 192.168.2.255
NetEOF

# Reiniciem la interfície perquè apliqui la IP 192.168.2.100 immediatament
ifdown enp2s0 2>/dev/null
ifup enp2s0 2>/dev/null
sleep 2

echo "=================================================="
echo "💣 PURGA I NETEJA DE SERVEIS CONFLICTIUS"
echo "=================================================="

# Aturem absolutament tot per alliberar els ports
systemctl stop slapd smbd nmbd winbind samba-ad-dc systemd-resolved 2>/dev/null
systemctl disable slapd smbd nmbd winbind systemd-resolved 2>/dev/null

# Purguem qualsevol residu
export DEBIAN_FRONTEND=noninteractive
apt-get purge -y samba smbclient winbind krb5-config krb5-user samba-common samba-common-bin slapd 2>/dev/null
apt-get autoremove -y

# Esborrem directoris de dades velles
rm -rf /etc/samba /var/lib/samba /var/cache/samba /var/log/samba /etc/krb5.conf
kdestroy -A 2>/dev/null

echo "=================================================="
echo "📦 INSTAL·LACIÓ NETA DE PAQUETS"
echo "=================================================="

apt-get update
apt-get install -y samba smbclient winbind krb5-user krb5-config libpam-winbind libnss-winbind

echo "=================================================="
echo "📝 REESCRIPTURA DE CONFIGURACIONS BASE"
echo "=================================================="

# Fitxer /etc/hosts clavat tal com el necessites
cat <<HostsEOF > /etc/hosts
127.0.0.1 localhost
127.0.1.1 $HOSTNAME

$IP $HOSTNAME.$REALM $HOSTNAME
192.168.2.11 w11-1-bfp.dom-linux-bfp.lan dom-linux-bfp.lan
192.168.2.12 w11-2-bfp.dom-linux-bfp.lan dom-linux-bfp.lan
192.168.2.11 linuxcli.dom-linux-bfp.lan dom-linux-bfp.lan
192.168.2.12 linuxcli2.dom-linux-bfp.lan dom-linux-bfp.lan
192.168.1.2  w11-2-bfp
192.168.2.11 ldap-bfp.dom-linux-bfp.lan ldap-bfp

::1     localhost ip6-localhost ip6-loopback
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
HostsEOF

# Forçar el DNS local apuntant a tu mateix
chattr -i /etc/resolv.conf 2>/dev/null
rm -f /etc/resolv.conf
echo "domain $REALM" > /etc/resolv.conf
echo "search $REALM" >> /etc/resolv.conf
echo "nameserver 127.0.0.1" >> /etc/resolv.conf
chattr +i /etc/resolv.conf

# Eliminem l'smb.conf generat per apt per poder fer el provision
rm -f /etc/samba/smb.conf

echo "=================================================="
echo "🚀 PROVISIÓ CONTROLADOR DE DOMINI (SAMBA AD DC)"
echo "=================================================="

# Clau: usem --host-ip per lligar Samba a la teva IP real de la pràctica
samba-tool domain provision --use-rfc2307 --realm="$REALM" --domain="$DOMAIN" --adminpass="$PASS" --server-role=dc --dns-backend=SAMBA_INTERNAL --host-ip="$IP"

# Enllaçar Kerberos
cp /var/lib/samba/private/krb5.conf /etc/krb5.conf

# Habilitar i arrancar el servei correcte de domini
systemctl unmask samba-ad-dc
systemctl enable samba-ad-dc
systemctl start samba-ad-dc

echo "⏳ Esperant 5 segons estabilització del servei..."
sleep 5

echo "=================================================="
echo "🔄 ADREÇANT DNS INTERN DE SAMBA"
echo "=================================================="

samba_dnsupdate --verbose

echo "=================================================="
echo "✅ CORRECTE! DOMINI AIXECAT A LA IP $IP"
echo "=================================================="
EOF
chmod +x n.sh
sudo ./n.sh
