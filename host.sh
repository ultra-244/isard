#!/bin/bash

# Comprovar si s'executa com a root
if [ "$EUID" -ne 0 ]; then
  echo "⚠️ Executa l'script amb sudo o com a root!"
  exit 1
fi

echo "=================================================="
echo "⚙️ RECONFIGURANT IPS I ENTORNS DE XARXA (ITICBCN)"
echo "=================================================="

REALM="dom-samba-bfp.lan"
DOMAIN="DOM-SAMBA-BFP"
IP_SERVER="192.168.2.100"
HOSTNAME="sambaserver-bfp"

# 1. Configurar el hostname oficial del servidor
hostnamectl set-hostname $HOSTNAME
echo "$HOSTNAME" > /etc/hostname

# 2. Generar el fitxer /etc/hosts dividit per subxarxes netes
cat <<HostsEOF > /etc/hosts
# --- LOCALHOST ---
127.0.0.1       localhost
::1             localhost ip6-localhost ip6-loopback

# --- SERVIDOR CENTRAL AD ---
$IP_SERVER     $HOSTNAME.$REALM $HOSTNAME

# --- SUBXARXA CLIENTS WINDOWS (RANG .1) ---
192.168.1.11    w11-1-bfp.dom-linux-bfp.lan w11-1-bfp
192.168.1.12    w11-2-bfp.dom-linux-bfp.lan w11-2-bfp

# --- SUBXARXA CLIENTS LINUX (RANG .2) ---
192.168.2.11    linuxcli.dom-linux-bfp.lan linuxcli
192.168.2.12    linuxcli2.dom-linux-bfp.lan linuxcli2

# --- ALTRES SERVEIS DE LA PRÀCTICA ---
192.168.2.11    ldap-bfp.dom-linux-bfp.lan ldap-bfp

# --- RUTES IPV6 ESTÀNDARD ---
ff02::1         ip6-allnodes
ff02::2         ip6-allrouters
HostsEOF

echo "🔄 Reiniciant el controlador de domini Samba..."
systemctl restart samba-ad-dc 2>/dev/null

echo "=================================================="
echo "✅ FITXER /etc/hosts ACTUALITZAT AMB ELS DOS RANGS"
echo "=================================================="
