#!/bin/bash

# Comprovació de privilegis de superusuari (root)
if [ "$EUID" -ne 0 ]; then
  echo "Si us plau, executa aquest script com a root o utilitzant sudo."
  exit 1
fi

echo "Configurant el fitxer /etc/hosts..."

# Escriure el contingut directament al fitxer /etc/hosts
cat << 'EOF' > /etc/hosts
127.0.0.1       localhost
::1             localhost ip6-localhost ip6-loopback

192.168.2.100   sambaserver-bfp.dom-samba-bfp.lan sambaserver-bfp

192.168.1.11    w11-1-bfp.dom-linux-bfp.lan w11-1-bfp
192.168.1.12    w11-2-bfp.dom-linux-bfp.lan w11-2-bfp

192.168.2.11    linuxcli.dom-linux-bfp.lan linuxcli
192.168.2.12    linuxcli2.dom-linux-bfp.lan linuxcli2

192.168.2.11    ldap-bfp.dom-linux-bfp.lan ldap-bfp

ff02::1         ip6-allnodes
ff02::2         ip6-allrouters
EOF

echo "Fitxer /etc/hosts actualitzat correctament!"
