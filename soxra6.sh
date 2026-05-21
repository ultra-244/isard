#!/bin/bash

# ==============================================================================
# Configuració de variables de manera interactiva
# ==============================================================================
echo "==================================================================="
echo " Iniciant la integració de sistemes operatius (RA6-A1)             "
echo " Si us plau, respon a les següents preguntes per configurar-ho:    "
echo "==================================================================="

read -p "1. Introdueix el nom del HOST (ex. sambaserver-abc): " HOSTNAME
read -p "2. Introdueix la IP del servidor (ex. 192.168.2.100): " IP_SERVER
read -p "3. Introdueix el REALM del domini en MAJÚSCULES (ex. DOM-SAMBA-ABC.LAN): " DOMAIN_REALM
read -p "4. Introdueix el nom NETBIOS del domini (ex. DOM-SAMBA-ABC): " DOMAIN_NETBIOS

echo "5. Introdueix la contrasenya d'Administrador i dels usuaris."
echo "   (ATENCIÓ: Ha de complir requisits de complexitat: Majúscules, minúscules i números/símbols)"
read -s -p "   Contrasenya: " ADMIN_PASS
echo "" # Salt de línia després d'escriure la contrasenya oculta

echo "========================================================"
echo " Resum de dades introduïdes:                            "
echo " Domini: $DOMAIN_REALM | Servidor: $HOSTNAME            "
echo " IP: $IP_SERVER        | NetBIOS: $DOMAIN_NETBIOS       "
echo "========================================================"
echo "Iniciant la instal·lació en 3 segons..."
sleep 3

# 1. Configuració de xarxa i hostname
echo "[*] Configurant el nom del servidor i l'arxiu hosts..."
hostnamectl set-hostname $HOSTNAME
# Afegim la resolució local si no existeix
grep -q "$IP_SERVER $HOSTNAME.$DOMAIN_REALM" /etc/hosts || echo "$IP_SERVER $HOSTNAME.$DOMAIN_REALM $HOSTNAME" >> /etc/hosts

# Pre-configuració de Kerberos per evitar pantalles interactives durant apt-get
echo "krb5-config krb5-config/default_realm string $DOMAIN_REALM" | debconf-set-selections
echo "krb5-config krb5-config/admin_server string $HOSTNAME.$DOMAIN_REALM" | debconf-set-selections
echo "krb5-config krb5-config/kerberos_servers string $HOSTNAME.$DOMAIN_REALM" | debconf-set-selections

export DEBIAN_FRONTEND=noninteractive

# Instal·lació de paquets necessaris per Samba AD DC i NFS
echo "[*] Instal·lant paquets (Samba, Kerberos, winbind, nfs-kernel-server)..."
apt-get update
apt-get install -y samba smbclient winbind libpam-winbind libnss-winbind krb5-config krb5-user acl nfs-kernel-server

# 2. Aturar serveis antics
echo "[*] Aturant i desactivant els serveis clàssics de Samba..."
systemctl stop smbd nmbd winbind
systemctl disable smbd nmbd winbind

# 3. Provisió del domini Samba AD DC
echo "[*] Provisionant el domini Active Directory..."
# Fem backup del smb.conf original
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

# Copiar l'arxiu de Kerberos generat per Samba al directori del sistema
cp /var/lib/samba/private/krb5.conf /etc/krb5.conf

# 4. Activar el servei unificat de Samba AD DC
echo "[*] Activant el servei samba-ad-dc..."
systemctl unmask samba-ad-dc
systemctl enable samba-ad-dc
systemctl start samba-ad-dc

# Esperar uns segons per assegurar que el servei està responent
sleep 5

# 5. Gestió d'usuaris i grups
echo "[*] Creant usuaris i grups de domini..."
samba-tool user create usuari1 "$ADMIN_PASS"
samba-tool user create usuari2 "$ADMIN_PASS"
samba-tool group add g_samba
samba-tool group addmembers g_samba usuari1,usuari2

# 6. Estructura de directoris
echo "[*] Creant estructura de carpetes compartides..."
mkdir -p /intern /compartit/sox /dades_windows /dades_linux

# Permisos a nivell de sistema de fitxers (Linux)
chmod 700 /intern
chmod 755 /compartit
chmod 777 /compartit/sox
chmod 777 /dades_windows
chmod 777 /dades_linux

# 7. Configuració de recursos compartits a Samba
echo "[*] Configurant l'arxiu smb.conf per als recursos compartits..."
cat <<EOF >> /etc/samba/smb.conf

[intern]
    path = /intern
    browseable = yes
    read only = yes
    invalid users = @"Domain Users"

[compartit]
    path = /compartit
    browseable = yes
    read only = yes
    valid users = @"Domain Users"

[sox]
    path = /compartit/sox
    browseable = yes
    read only = no
    valid users = @g_samba
    write list = @g_samba

[dades_windows]
    path = /dades_windows
    browseable = yes
    read only = no
    guest ok = yes
EOF

echo "[*] Reiniciant samba-ad-dc per aplicar els recursos compartits..."
systemctl restart samba-ad-dc

# 8. Configuració de Linux NFS
echo "[*] Configurant exportació via NFS (/dades_linux)..."
grep -q "/dades_linux" /etc/exports || echo "/dades_linux *(rw,sync,no_subtree_check)" >> /etc/exports
exportfs -a
systemctl restart nfs-kernel-server

echo "========================================================"
echo " Instal·lació completada amb èxit!                      "
echo "========================================================"
echo "Comprovacions ràpides que pots fer al servidor:"
echo " 1. systemctl status samba-ad-dc"
echo " 2. smbclient -L localhost -U%"
echo " 3. samba-tool user list"
echo "========================================================"
