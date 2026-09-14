# ⚡ Termo-Kali

### Kali Linux on Termux & Android — No Root Required

**Termo-Kali** installs and runs a Kali Linux environment on Android using **Termux + PRoot**, with an optional **Xfce + TigerVNC desktop**.

> Simple setup. Reliable installation. Portable Kali environment.

[![Platform](https://img.shields.io/badge/Platform-Android-3DDC84?style=flat-square&logo=android&logoColor=white)](https://www.android.com/)
[![Termux](https://img.shields.io/badge/Termux-Supported-000000?style=flat-square&logo=terminal&logoColor=white)](https://termux.dev/)
[![Shell](https://img.shields.io/badge/Shell-Bash-4EAA25?style=flat-square&logo=gnu-bash&logoColor=white)](https://www.gnu.org/software/bash/)
[![License](https://img.shields.io/badge/License-MIT-blue?style=flat-square)](LICENSE)

---

## ✨ Features

- 🚀 One-command Kali installation
- 📦 Automatic Termux dependency handling
- 🧭 Automatic ARM64/ARM/x86 architecture detection
- 🔒 Rootfs archive validation before extraction
- 🔁 Safe re-runs without unnecessary reinstallation
- 📝 Persistent installation logs
- 💻 PRoot-based Kali environment without Android root
- 🖥️ Optional Kali Xfce desktop
- 🐯 TigerVNC desktop server
- 🔐 VNC bound to `127.0.0.1` by default
- 🧰 Desktop start/stop/restart/status/password commands
- ⚡ CLI-first base installation to keep the initial setup lighter

---

## 📋 Requirements

- Android device
- Termux
- Stable internet connection
- At least ~2 GB free storage for the base installation
- Additional storage for Xfce and desktop packages

Use a maintained Termux distribution such as the F-Droid or official GitHub-release builds.

> The Google Play Store version of Termux is deprecated for general use.

---

## 🚀 Quick Start

### Install Termo-Kali

```bash
pkg update -y && pkg upgrade -y
pkg install git -y

git clone https://github.com/kaztral-ar/termokali.git
cd termokali

chmod +x termo-kali.sh
./termo-kali.sh
```

Or:

```bash
bash termo-kali.sh
```

> Do not use `sh termo-kali.sh`; the installer uses Bash-specific features.

---

## ▶️ Start Kali

From Termux:

```bash
~/start-kali.sh
```

Verify Kali from inside the environment:

```bash
cat /etc/os-release
```

Exit with:

```bash
exit
```

---

## 🖥️ Kali Xfce Desktop

Termo-Kali includes a separate desktop manager using the same practical **PRoot + Xfce + VNC** model used by established Android Linux projects. The implementation is kept separate from the base installer so a CLI-only installation does not have to download the full graphical stack.

### 1. Install Xfce + TigerVNC

Run this **from Termux**, outside the Kali shell:

```bash
cd ~/Termokali
chmod +x termo-kali-desktop.sh
./termo-kali-desktop.sh install
```

It installs:

- `kali-desktop-xfce`
- `tigervnc-standalone-server`
- `dbus-x11`
- `xauth`

### 2. Set a VNC password

```bash
./termo-kali-desktop.sh passwd
```

### 3. Start the desktop

```bash
./termo-kali-desktop.sh start
```

Open your Android VNC client and connect to:

```text
127.0.0.1:5901
```

### Desktop controls

```bash
./termo-kali-desktop.sh start
./termo-kali-desktop.sh stop
./termo-kali-desktop.sh restart
./termo-kali-desktop.sh status
./termo-kali-desktop.sh passwd
```

> The VNC server is intentionally localhost-only by default. This avoids exposing the desktop service to other devices on the network.

> Do not use `systemctl` for this setup. Kali is running inside PRoot on Android rather than as a normal booted system with systemd.

---

## 🔧 Installation Flow

```text
Termux
  │
  ├── Check environment
  ├── Check storage
  ├── Install dependencies
  ├── Detect architecture
  ├── Download Kali rootfs
  ├── Validate archive
  ├── Extract rootfs
  └── Create start-kali.sh
           │
           ▼
      Kali CLI
           │
           └── Optional Xfce + TigerVNC
                         │
                         ▼
                  Android VNC client
```

Generated files:

```text
~/start-kali.sh
~/kali-help.txt
~/.termo-kali/install.log
```

---

## 🛠️ Troubleshooting

### Check the installer log

```bash
cat ~/.termo-kali/install.log
```

### Check free storage

```bash
df -h "$HOME"
```

### Repair interrupted Kali packages

Run these **inside Kali**:

```bash
dpkg --configure -a
apt-get -f install -y
apt-get update
```

If the error says:

```text
/usr/share/debconf/frontend: not found
```

repair `debconf` before installing the desktop:

```bash
apt-get install --reinstall debconf -y
```

Then:

```bash
dpkg --configure -a
apt-get -f install -y
```

### Permission denied

```bash
chmod +x ~/start-kali.sh
```

### Stale installer lock

Only when no Termo-Kali installer is running:

```bash
rm -f ~/.termo-kali/lock
```

---

## 🔁 Re-run

The base installer is safe to run again:

```bash
./termo-kali.sh
```

Desktop management is separate:

```bash
./termo-kali-desktop.sh status
```

---

## 🗑️ Uninstall Kali

```bash
rm -rf ~/kali-fs ~/kali-binds ~/start-kali.sh ~/kali-help.txt ~/.termo-kali
```

This does not uninstall Termux.

---

## 📁 Project Structure

```text
Termokali/
│
├── termo-kali.sh
├── termo-kali-desktop.sh
├── termo.txt
├── README.md
├── CONTRIBUTING.md
├── CODE_OF_CONDUCT.md
└── LICENSE
```

---

## 🤝 Contributing

Bug reports, feature requests, documentation improvements, testing and code contributions are welcome.

See `CONTRIBUTING.md` for contribution guidelines.

---

## 📜 License

Termo-Kali is licensed under the **MIT License**.

See `LICENSE` for the full license text.

---

## ⚠️ Disclaimer

Termo-Kali is an unofficial community project. It is not affiliated with, sponsored by, or endorsed by Kali Linux, Offensive Security, Termux, or Andronix.

Use Kali Linux and its tools responsibly and only on systems and networks where you have authorization.

---

<div align="center">

### ⚡ Termo-Kali

**Kali Linux • Termux • Android • No Root**

</div>
