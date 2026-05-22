#!/bin/bash
# ==============================================================================
# EXERCICI 1: Instal·lació i provisió del controlador de domini Samba (AD DC)
# ==============================================================================

echo "==================================================================="
echo " CONFIGURACIÓ INTERACTIVA DEL DOMINI"
echo "==================================================================="
echo "Prem [INTRO] per mantenir el valor per defecte entre claudàtors."
echo ""

# Petició de variables amb valors per defecte
read -p "Introdueix el DOMAIN_REALM [DOM-SAMBA-BFP.LAN]: " input_realm
DOMAIN_REALM=${input_realm:-"DOM-SAMBA-BFP.LAN"}

read -p "Introdueix el DOMAIN_NETBIOS [DOM-SAMBA-BFP]: " input_netbios
DOMAIN_NETBIOS=${input_netbios:-"DOM-SAMBA-BFP"}

read -p "Introdueix el HOSTNAME [sambaserver-bfp]: " input_hostname
HOSTNAME=${input_hostname:-"sambaserver-bfp"}

read -p "Introdueix la IP_SERVER [192.168.2.100]: " input_ip
IP_SERVER=${input_ip:-"192.168.2.100"}

read -p "Introdueix la contrasenya d'administrador [S3cur3P@ssw0rd!]: " input_pass
ADMIN_PASS=${input_pass:-"S3cur3P@ssw0rd!"}

echo ""
echo "[*] Configurant hostname i resolució local..."
hostnamectl set-hostname $HOSTNAME
grep -q "$IP_SERVER $HOSTNAME.$DOMAIN_REALM" /etc/hosts || echo "$IP_SERVER $HOSTNAME.$DOMAIN_REALM $HOSTNAME" >> /etc/hosts

# Pre-configuració de Kerberos per evitar finestres interactives
echo "krb5-config krb5-config/default_realm string $DOMAIN_REALM" | debconf-set-selections
echo "krb5-config krb5-config/admin_server string $HOSTNAME.$DOMAIN_REALM" | debconf-set-selections
echo "krb5-config krb5-config/kerberos_servers string $HOSTNAME.$DOMAIN_REALM" | debconf-set-selections
export DEBIAN_FRONTEND=noninteractive

echo "[*] Instal·lant paquets de Samba AD DC..."
apt-get update
apt-get install -y samba smbclient winbind libpam-winbind libnss-winbind krb5-config krb5-user acl nfs-kernel-server

echo "[*] Aturant i desactivant serveis clàssics de Samba..."
systemctl stop smbd nmbd winbind
systemctl disable smbd nmbd winbind

echo "[*] Provisionant el domini $DOMAIN_REALM..."
if [ -f /etc/samba/smb.conf ]; then
    mv /etc/samba/smb.conf /etc/samba/smb.conf.bak
fi

samba-tool domain provision \
    --use-rfc2307 \
    --realm=$DOMAIN_REALM \
    --domain=$DOMAIN_NETBIOS \
    --server-role=dc \
    --dns-backend=SAMBA_INTERNAL \
    --adminpass="$ADMIN_PASS"

cp /var/lib/samba/private/krb5.conf /etc/krb5.conf

echo "[*] Activant el servei unificat samba-ad-dc..."
systemctl unmask samba-ad-dc
systemctl enable samba-ad-dc
systemctl start samba-ad-dc

echo "[*] Esperant que el servei s'estabilitzi..."
sleep 5

echo ""
echo "==================================================================="
echo " SORTIDES PER A LES CAPTURES DE L'EXERCICI 1"
echo "==================================================================="
echo "[Captura 1] Estat del servei (systemctl status samba-ad-dc):"
systemctl status samba-ad-dc --no-pager | head -n 15
echo ""
echo "[Captura 2] Recursos compartits per defecte (smbclient):"
smbclient -L localhost -U%
echo "==================================================================="
