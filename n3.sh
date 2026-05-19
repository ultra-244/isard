cat << 'EOF' > n.sh
#!/bin/bash

if [ "$EUID" -ne 0 ]; then
  echo "Aquest script s'ha d'executar amb sudo: sudo ./n.sh"
  exit
fi

echo "=================================================="
echo "💣 INSTAL·LACIÓ ABSOLUTA I CONFIGURACIÓ DE DOMINI"
echo "=================================================="

REALM="dom-samba-bfp.lan"
DOMAIN="DOM-SAMBA-BFP"
PASS="P@ssword2026!"
IP="192.168.2.100"
HOSTNAME="sambaserver-bfp"

echo "0. Configurant Hostname de la màquina..."
hostnamectl set-hostname $HOSTNAME
echo "$HOSTNAME" > /etc/hostname

echo "0.5. Configurant IP estàtica permanent a enp2s0..."
cat << NetEOF > /etc/network/interfaces
# Fitxer de configuració de xarxa generat per l'script
source /etc/network/interfaces.d/*

# Interfície loopback
auto lo
iface lo inet loopback

# Interfície enp2s0 (IP Estàtica per Samba)
auto enp2s0
iface enp2s0 inet static
    address $IP
    netmask 255.255.255.0
    network 192.168.2.0
    broadcast 192.168.2.255
NetEOF

# Apliquem el canvi d'IP immediatament aixecant la interfície
ifdown enp2s0 2>/dev/null
ifup enp2s0 2>/dev/null

echo "1. Matant absolutament tots els serveis que bloquegen ports..."
systemctl stop slapd smbd nmbd winbind samba-ad-dc systemd-resolved 2>/dev/null
systemctl disable slapd smbd nmbd winbind systemd-resolved 2>/dev/null

echo "2. Purgant paquets vells per evitar configuracions corruptes..."
export DEBIAN_FRONTEND=noninteractive
apt-get purge -y samba smbclient winbind krb5-config krb5-user samba-common samba-common-bin slapd 2>/dev/null
apt-get autoremove -y

echo "3. Netejant directoris de dades i memòria cau..."
rm -rf /etc/samba /var/lib/samba /var/cache/samba /var/log/samba /etc/krb5.conf
kdestroy -A 2>/dev/null

echo "4. Instal·lant paquets nets de fàbrica..."
apt-get update
apt-get install -y samba smbclient winbind krb5-user krb5-config libpam-winbind libnss-winbind

echo "5. Reescrivint completament el fitxer /etc/hosts..."
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

# The following lines are desirable for IPv6 capable hosts
::1     localhost ip6-localhost ip6-loopback
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
HostsEOF

echo "6. Configurant el sistema DNS local de Samba..."
chattr -i /etc/resolv.conf 2>/dev/null
rm -f /etc/resolv.conf
echo "domain $REALM" > /etc/resolv.conf
echo "search $REALM" >> /etc/resolv.conf
echo "nameserver 127.0.0.1" >> /etc/resolv.conf
chattr +i /etc/resolv.conf

echo "6.5. Eliminant configuració smb.conf residual..."
rm -f /etc/samba/smb.conf

echo "7. Executant la provisió de l'Active Directory..."
samba-tool domain provision --use-rfc2307 --realm="$REALM" --domain="$DOMAIN" --adminpass="$PASS" --server-role=dc --dns-backend=SAMBA_INTERNAL

echo "8. Enllaçant fitxer de Kerberos..."
cp /var/lib/samba/private/krb5.conf /etc/krb5.conf

echo "9. Engegant el servei correcte (samba-ad-dc)..."
systemctl unmask samba-ad-dc
systemctl enable samba-ad-dc
systemctl start samba-ad-dc

echo "10. Esperant l'estabilització del sistema (5 segons)..."
sleep 5

echo "11. Sincronitzant registres DNS interns..."
samba_dnsupdate --verbose

echo "=================================================="
echo "✅ CORRECTE! SERVIDORS REDREÇATS I DOMINI AIXECAT"
echo "=================================================="
EOF
chmod +x n.sh
sudo ./n.sh
