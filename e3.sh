#!/bin/bash
# ==============================================================================
# EXERCICI 3: Configuració de recursos compartits i nivells de seguretat
# ==============================================================================

echo "[*] Creant estructura de directoris locals..."
mkdir -p /intern /compartit/sox /dades_windows /dades_linux

echo "[*] Aplicant permisos a nivell de sistema de fitxers..."
chmod 700 /intern
chmod 755 /compartit
chmod 777 /compartit/sox
chmod 777 /dades_windows
chmod 777 /dades_linux

echo "[*] Configurant els recursos compartits al fitxer smb.conf..."
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

echo "[*] Reiniciant Samba per aplicar els canvis..."
systemctl restart samba-ad-dc

echo "[*] Configurant exportació de xarxa via Linux NFS..."
grep -q "/dades_linux" /etc/exports || echo "/dades_linux *(rw,sync,no_subtree_check)" >> /etc/exports
exportfs -a
systemctl restart nfs-kernel-server

echo ""
echo "==================================================================="
echo " SORTIDES PER A LES CAPTURES DE L'EXERCICI 3"
echo "==================================================================="
echo "[Captura 1] Permisos del sistema de fitxers de les carpetes creades:"
ls -ld /intern /compartit /compartit/sox /dades_windows /dades_linux
echo ""
echo "[Captura 2] Bloque de definició de recursos a /etc/samba/smb.conf:"
tail -n 25 /etc/samba/smb.conf
echo ""
echo "[Captura 3] Configuració del fitxer d'exportacions NFS (/etc/exports):"
tail -n 2 /etc/exports
echo "==================================================================="
