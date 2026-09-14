#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail

ROOTFS="$HOME/kali-fs"
GREEN='\033[1;32m'; RED='\033[1;31m'; CYAN='\033[1;36m'; YELLOW='\033[1;33m'; RESET='\033[0m'

info(){ printf '%b[INFO]%b %s\n' "$CYAN" "$RESET" "$*"; }
ok(){ printf '%b[OK]%b %s\n' "$GREEN" "$RESET" "$*"; }
warn(){ printf '%b[WARN]%b %s\n' "$YELLOW" "$RESET" "$*"; }
err(){ printf '%b[ERROR]%b %s\n' "$RED" "$RESET" "$*" >&2; }

require_kali(){
  if [[ ! -x "$ROOTFS/bin/bash" ]]; then
    err "Kali is not installed. Run ./termo-kali.sh first."
    exit 1
  fi
  if [[ ! -x "$ROOTFS/usr/bin/dpkg" ]]; then
    err "Kali rootfs is incomplete: /usr/bin/dpkg is missing."
    exit 1
  fi
}

run_kali(){
  HOME=/root \
  USER=root \
  LOGNAME=root \
  PATH=/usr/local/sbin:/usr/local/bin:/bin:/usr/bin:/sbin:/usr/sbin:/usr/games:/usr/local/games \
  TERM="${TERM:-xterm-256color}" \
  LANG=C.UTF-8 \
  LC_ALL=C.UTF-8 \
  proot --link2symlink -0 \
    -r "$ROOTFS" \
    -b /dev \
    -b /proc \
    -b /sys \
    -b "$ROOTFS/root:/dev/shm" \
    -w /root \
    /bin/bash --login -c "$1"
}

install_desktop(){
  info "Installing Kali Xfce + TigerVNC..."
  run_kali '
set -e
export DEBIAN_FRONTEND=noninteractive

if [ ! -x /usr/bin/dpkg ]; then
  echo "dpkg is missing; Kali rootfs is incomplete."
  exit 10
fi

apt-get update

# Some minimal rootfs images can lose the debconf frontend after an interrupted
# package operation. Bootstrap it before installing the desktop metapackage.
if [ ! -x /usr/share/debconf/frontend ]; then
  echo "[INFO] debconf frontend is missing; bootstrapping debconf..."
  tmp=$(mktemp -d)
  cd "$tmp"
  apt-get download debconf
  dpkg --unpack ./debconf_*.deb
  cd /
  rm -rf "$tmp"
fi

dpkg --configure -a || true
apt-get -f install -y
apt-get update
apt-get install -y kali-desktop-xfce tigervnc-standalone-server dbus-x11 xauth

mkdir -p /root/.vnc
cat > /root/.vnc/xstartup <<"XSTARTUP"
#!/bin/sh
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
export SHELL=/bin/bash
export XDG_CURRENT_DESKTOP=XFCE
export XDG_SESSION_DESKTOP=xfce
export XDG_CONFIG_DIRS=/etc/xdg/xdg-xfce:/etc/xdg
exec dbus-launch --exit-with-session startxfce4
XSTARTUP
chmod +x /root/.vnc/xstartup

cat > /usr/local/bin/kali-vnc-start <<"VNCSTART"
#!/bin/sh
set -e
if vncserver -list 2>/dev/null | grep -q ':1'; then
  echo "Kali desktop is already running on :1 (127.0.0.1:5901)."
  exit 0
fi
vncserver :1 -geometry 1280x720 -depth 24 -localhost yes
printf 'Kali Xfce started. Connect your VNC client to 127.0.0.1:5901\n'
VNCSTART
chmod +x /usr/local/bin/kali-vnc-start

cat > /usr/local/bin/kali-vnc-stop <<"VNCSTOP"
#!/bin/sh
vncserver -kill :1 2>/dev/null || true
VNCSTOP
chmod +x /usr/local/bin/kali-vnc-stop

cat > /usr/local/bin/kali-vnc-status <<"VNCSTATUS"
#!/bin/sh
vncserver -list 2>/dev/null || true
VNCSTATUS
chmod +x /usr/local/bin/kali-vnc-status

cat > /usr/local/bin/kali-desktop <<"DESKTOP"
#!/bin/sh
case "${1:-start}" in
  start) exec /usr/local/bin/kali-vnc-start ;;
  stop) exec /usr/local/bin/kali-vnc-stop ;;
  restart) /usr/local/bin/kali-vnc-stop; exec /usr/local/bin/kali-vnc-start ;;
  status) exec /usr/local/bin/kali-vnc-status ;;
  passwd) exec vncpasswd ;;
  *) echo "Usage: kali-desktop {start|stop|restart|status|passwd}"; exit 2 ;;
esac
DESKTOP
chmod +x /usr/local/bin/kali-desktop

echo
echo "Kali Xfce desktop installation completed."
echo "Set your VNC password with: kali-desktop passwd"
echo "Start with: kali-desktop start"
echo "Connect to: 127.0.0.1:5901"
'
  ok "Desktop setup completed."
  warn "Kali 2026.x ARM64 + PRoot/Xfce has an upstream compatibility issue affecting gdk-pixbuf/Glycin on some systems. If VNC connects and Xfce exits after a few seconds, run ./termo-kali.sh --doctor and check the upstream issue before changing the installer."
}

case "${1:-help}" in
  install)
    require_kali
    install_desktop
    ;;
  start|stop|restart|status|passwd)
    require_kali
    run_kali "if command -v kali-desktop >/dev/null 2>&1; then kali-desktop $1; else echo 'Desktop is not installed. Run: ~/termo-kali-desktop.sh install'; exit 1; fi"
    ;;
  help|-h|--help)
    cat <<'HELP'
Termo-Kali Desktop

Usage:
  ~/termo-kali-desktop.sh install    Install Xfce + TigerVNC
  ~/termo-kali-desktop.sh passwd     Set/change VNC password
  ~/termo-kali-desktop.sh start      Start Xfce desktop
  ~/termo-kali-desktop.sh stop       Stop Xfce desktop
  ~/termo-kali-desktop.sh restart    Restart Xfce desktop
  ~/termo-kali-desktop.sh status     Show VNC status

VNC address:
  127.0.0.1:5901

Notes:
  - The VNC server is localhost-only by default.
  - Do not use systemctl inside the PRoot environment.
HELP
    ;;
  *)
    err "Unknown command: $1"
    exit 2
    ;;
esac
