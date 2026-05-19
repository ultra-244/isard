cat << 'EOF' > n.sh
#!/bin/bash

echo "🚀 CORREGINT L'ERROR DE DNS D'ISARDVDI..."

REALM="dom-samba-bfp.lan"
DOMAIN="DOM-SAMBA-BFP"
PASS="P@ssword2026!"
IP="192.168.2.100"
HOSTNAME="sambaserver-bfp"

# 1. Aturar serveis i netejar a fons
systemctl stop slapd smbd nmbd winbind samba-ad-dc systemd-resolved 2>/dev/null
killall samba smbd nmbd winbind 2>/dev/null
rm -f /etc/samba/smb.conf
rm -rf /var/lib/samba/* /var/cache/samba/*

# 2. Configurar Hosts EXACTE per evitar la IP d'IsardVDI
# (Fixa't que hem eliminat la línia 127.0.1.1, això és la clau)
cat <<HostsEOF > /etc/hosts
127.0.0.1 localhost
$IP $HOSTNAME.$REALM $HOSTNAME

192.168.2.11 w11-1-bfp.dom-linux-bfp.lan dom-linux-bfp.lan
192.168.2.12 w11-2-bfp.dom-linux-bfp.lan dom-linux-bfp.lan
192.168.2.11 linuxcli.dom-linux-bfp.lan dom-linux-bfp.lan
192.168.2.12 linuxcli2.dom-linux-bfp.lan dom-linux-bfp.lan
192.168.1.2  w11-2-bfp
192.168.2.11 ldap-bfp.dom-linux-bfp.lan ldap-bfp
HostsEOF

# 3. Forçar DNS local
chattr -i /etc/resolv.conf 2>/dev/null
rm -f /etc/resolv.conf
echo "domain $REALM" > /etc/resolv.conf
echo "search $REALM" >> /etc/resolv.conf
echo "nameserver 127.0.0.1" >> /etc/resolv.conf
chattr +i /etc/resolv.conf

# 4. Provisió forçant la interfície i bloquejant les altres
samba-tool domain provision --use-rfc2307 --realm="$REALM" --domain="$DOMAIN" --adminpass="$PASS" --server-role=dc --dns-backend=SAMBA_INTERNAL --host-ip="$IP" --option="interfaces=lo enp2s0" --option="bind interfaces only=yes"

# 5. Aplicar Kerberos i engegar
cp /var/lib/samba/private/krb5.conf /etc/krb5.conf
systemctl unmask samba-ad-dc
systemctl enable samba-ad-dc
systemctl start samba-ad-dc

echo "⏳ Esperant 10 segons que el servidor DNS intern de Samba obri els ports..."
sleep 10

# 6. Sincronització DNS (Ara sí que trobarà el port 53 obert a la IP correcta)
samba_dnsupdate --verbose

echo "=================================================="
echo "✅ CORRECTE! DOMINI AIXECAT I LLEST!"
echo "=================================================="
EOF
chmod +x n.sh
sudo ./n.sh
