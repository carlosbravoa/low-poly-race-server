#!/bin/sh
# Installs or updates the Low Poly Race server on a Linux box (Debian, Ubuntu, Amazon Linux, Fedora...) as a
# systemd service. Run as root:
#   sudo ./install.sh https://.../raceserver-0.1.0-linux-x86_64.tar.gz [SHA256]
# The settings live in /etc/raceserver.env (edit, then: systemctl restart raceserver).
set -e
URL=${1:?usage: install.sh TARBALL_URL [SHA256]}
SUM=$2
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
cd "$TMP"
if command -v curl >/dev/null; then curl -fsSL -o server.tar.gz "$URL"; else wget -qO server.tar.gz "$URL"; fi
if [ -n "$SUM" ]; then echo "$SUM  server.tar.gz" | sha256sum -c - >/dev/null || { echo "install.sh: the tarball's SHA-256 does not match"; exit 1; }; fi
tar -xzf server.tar.gz
DIR=$(find . -maxdepth 1 -type d -name 'raceserver-*' | head -1)
[ -n "$DIR" ] || { echo "install.sh: not a raceserver tarball"; exit 1; }
id raceserver >/dev/null 2>&1 || useradd --system --home /opt/raceserver --shell /usr/sbin/nologin raceserver 2>/dev/null || useradd -r -d /opt/raceserver -s /sbin/nologin raceserver
mkdir -p /opt/raceserver
cp -r "$DIR"/raceserver "$DIR"/tracks "$DIR"/VERSION "$DIR"/README.txt /opt/raceserver/
chmod 755 /opt/raceserver/raceserver
chown -R raceserver:raceserver /opt/raceserver
cp "$DIR"/raceserver.service /etc/systemd/system/raceserver.service
if [ ! -f /etc/raceserver.env ]; then
  cat > /etc/raceserver.env <<ENV
# Low Poly Race server settings (systemctl restart raceserver after a change)
PORT=7777
NAME=Low Poly Race
PASSWORD=
ROOMS=8
SNAPSHOT_HZ=30
# more raceserver options, e.g. --no-beacon --players 32
EXTRA=
ENV
fi
systemctl daemon-reload
systemctl enable raceserver >/dev/null 2>&1 || true
systemctl restart raceserver
echo "raceserver $(cat /opt/raceserver/VERSION) installed: UDP port $(. /etc/raceserver.env; echo $PORT). Settings in /etc/raceserver.env; logs: journalctl -u raceserver -f"
