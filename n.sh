#!/bin/bash

# Comprovem si s'executa com a root
if [ "$EUID" -ne 0 ]; then
  echo "Aquest script s'ha d'executar amb sudo: sudo ./preparar_domini.sh"
  exit
fi

echo "=================================================="
echo "💣 MODE DESTRUCCIÓ I RECREACIÓ TOTAL DE SAMBA AD DC"
echo "=================================================="

# Variables del domini
REALM="dom-samba-bfp.lan"
DOMAIN="DOM-SAMBA-BFP"
PASS="P@ssword2026!"
IP="192.168.2.100"
HOSTNAME="sambaserver-bfp"

echo "1. Aturant tots els serveis conflictius..."
systemctl stop smbd nmbd winbind samba-ad-dc systemd-resolved 2>/dev/null
systemctl disable systemd-resolved 2>/dev/null

echo "2. Desinstal·lant completament Samba i Kerberos..."
# Evitem que l'assistent d'instal·lació ens faci preguntes per pantalla
export DEBIAN_FRONTEND=noninteractive
apt-get purge -y samba smbclient winbind krb5-config krb5-user samba-common samba-common-bin
apt-get autoremove -y

echo "3. Eliminant qualsevol rastre de configuració vella..."
rm -rf /etc/samba /var/lib/samba /var/cache/samba /var/log/samba /etc/krb5.conf
kdestroy -A 2>/dev/null

echo "4. Tornant a instal·lar Samba net de fàbrica..."
apt-get update
apt-get install -y samba smbclient winbind krb5-user krb5-config libpam-winbind libnss-winbind

echo "5. Configurant /etc/hosts correctament..."
sed -i "/$HOSTNAME/d" /etc/hosts
echo "$IP $HOSTNAME.$REALM $HOSTNAME" >> /etc/hosts

echo "6. Alliberant el port 53 (DNS) i forçant resolv.conf..."
chattr -i /etc/resolv.conf 2>/dev/null # Per si de cas estava bloquejat
rm -f /etc/resolv.conf
echo "domain $REALM" > /etc/resolv.conf
echo "search $REALM" >> /etc/resolv.conf
echo "nameserver 127.0.0.1" >> /etc/resolv.conf
chattr +i /etc/resolv.conf # El bloquegem perquè Debian no el canviï sol al reiniciar

echo "7. Creant el domini Active Directory (Provisió)..."
# Esborrem l'smb.conf que crea la nova instal·lació per defecte
rm -f /etc/samba/smb.conf 
samba-tool domain provision --use-rfc2307 --realm="$REALM" --domain="$DOMAIN" --adminpass="$PASS" --server-role=dc --dns-backend=SAMBA_INTERNAL

echo "8. Configurant el client de Kerberos..."
cp /var/lib/samba/private/krb5.conf /etc/krb5.conf

echo "9. Desactivant serveis clàssics i iniciant Active Directory..."
systemctl stop smbd nmbd winbind 2>/dev/null
systemctl disable smbd nmbd winbind 2>/dev/null
systemctl unmask samba-ad-dc
systemctl enable samba-ad-dc
systemctl start samba-ad-dc

echo "10. Esperant 5 segons a que arrenqui el motor de Samba..."
sleep 5

echo "11. Forçant l'escriptura dels registres DNS (SRV)..."
samba_dnsupdate --verbose --force

echo "=================================================="
echo "✅ DESTRUCCIÓ I INSTAL·LACIÓ FINALITZADA AMB ÈXIT!"
echo "--------------------------------------------------"
echo "Dades per unir el teu Windows:"
echo "- Domini: $REALM"
echo "- Usuari: Administrator"
echo "- Contrasenya: $PASS"
echo "=================================================="