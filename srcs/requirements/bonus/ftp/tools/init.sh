#!/bin/sh
set -e

PWFILE=/etc/pure-ftpd/pureftpd.passwd
DBFILE=/etc/pure-ftpd/pureftpd.pdb

FTP_PASSWORD=$(tr -d '\n' < /run/secrets/ftp_password)

FTP_UID=$(id -u nobody)
FTP_GID=$(id -g nobody)

mkdir -p /etc/pure-ftpd

pure-pw userdel "$FTP_USER" -f "$PWFILE" > /dev/null 2>&1 || true

printf '%s\n%s\n' "$FTP_PASSWORD" "$FTP_PASSWORD" | \
    pure-pw useradd "$FTP_USER" \
        -f "$PWFILE" \
        -u "$FTP_UID" \
        -g "$FTP_GID" \
        -d /var/www/html

pure-pw mkdb "$DBFILE" -f "$PWFILE"
chmod 600 "$PWFILE" "$DBFILE"

echo "FTP user '$FTP_USER' -> uid=$FTP_UID gid=$FTP_GID, jailed in /var/www/html"
echo "Passive ports ${FTP_PASV_MIN}-${FTP_PASV_MAX}, advertising ${FTP_PASV_ADDRESS}"
echo "Starting Pure-FTPd..."

# Flags do pure-ftpd:
#   -l puredb:FILE   autenticacao pela base PureDB (sem PAM)
#   -4               apenas IPv4
#   -E               proibe logins anonimos
#   -A               chroot para todos excepto root
#   -H               nao resolve hostnames (arranque mais rapido)
#   -S 21            escuta na porta 21
#   -p min:max       range de portas passivas (publicado no compose)
#   -P ip            IP anunciado nas respostas PASV
#   -U 133:022       umask de ficheiros:diretorios
#
# Sem -B: corre em foreground, portanto e o PID 1.
# NOTA: nunca colocar comentarios depois de '\' — o backslash tem de ser
# o ultimo caracter da linha, senao o texto e passado como argumento.
exec pure-ftpd \
    -l puredb:"$DBFILE" \
    -4 \
    -E \
    -A \
    -H \
    -S 21 \
    -p "${FTP_PASV_MIN}:${FTP_PASV_MAX}" \
    -P "${FTP_PASV_ADDRESS}" \
    -U 133:022
