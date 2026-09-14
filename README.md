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
- 🩺 Built-in diagnostics with `--doctor`
- 🛠️ Built-in APT/dpkg repair with `--repair`
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

### Check the installation

```bash
./termo-kali.sh --status
./termo-kali.sh --doctor
```

---

## ▶️ Start Kali

From Termux:

```bash
~/start-kali.sh
```

Verify Kali from inside the environment:

```bash
cat /etc/os-release
termokali-info
```

Exit with:

```bash
exit
```

---

## 🩺 Diagnostics and Repair

If Kali starts but a package operation fails, first run:

```bash
./termo-kali.sh --doctor
```

For an interrupted `dpkg`/APT state:

```bash
./termo-kali.sh --repair
```

The repair command also bootstraps the `debconf` package when `/usr/share/debconf/frontend` is missing.

Inside Kali, the equivalent helper is:

```bash
termokali-repair
```

The installer log is stored at:

```text
~/.termo-kali/install.log
```

For normal Kali upgrades, use the current Kali workflow:

```bash
apt update
apt full-upgrade -y
```

---

## 🖥️ Kali Xfce Desktop

Termo-Kali includes a separate desktop manager using the practical **PRoot + Xfce + VNC** model. The implementation is kept separate from the base installer so a CLI-only installation does not have to download the full graphical stack.

### 1. Install Xfce + TigerVNC

Run this **from Termux**, outside the Kali shell:

```bash
cd ~/termokali
chmod +x termo-kali-desktop.sh
./termo-kali-desktop.sh install
```

If your clone is stored in a different directory, `cd` into that directory instead. Android/Termux paths are case-sensitive.

It installs:

- `kali-desktop-xfce`
- `tigervnc-standalone-server`
- `dbus-x11`
- `xauth`

The desktop installer repairs a missing `debconf` frontend before installing the desktop packages.

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

### ⚠️ Kali 2026.x ARM64/Xfce note

There is an open upstream Kali issue affecting some **NetHunter Rootless/PRoot + ARM64 + Xfce 4.20** installations. Symptoms can include VNC connecting successfully and then the Xfce session exiting after a few seconds because of `gdk-pixbuf`/Glycin and sandbox compatibility problems.

This is an upstream compatibility issue, not a Termo-Kali installer failure. Termo-Kali therefore reports the condition rather than applying an unverified workaround that could damage the desktop environment.

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
  ├── Configure Kali APT sources
  ├── Create repair/info helpers
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

### `/usr/bin/env: No such file or directory`

Older Termo-Kali launchers used `/usr/bin/env` inside the PRoot rootfs. The current launcher does **not** depend on `/usr/bin/env` and sets the environment directly before starting `/bin/bash`.

Update the repository and regenerate the launcher:

```bash
cd ~/termokali
git pull --ff-only
chmod +x termo-kali.sh
./termo-kali.sh --repair
```

Then start Kali again:

```bash
~/start-kali.sh
```

### `/usr/share/debconf/frontend: not found`

Run the repair command from Termux:

```bash
./termo-kali.sh --repair
```

Or from inside Kali:

```bash
termokali-repair
```

The repair process bootstraps `debconf`, configures pending packages, fixes dependencies, and refreshes the package lists.

### APT upgrade errors

Kali recommends `apt full-upgrade`, not plain `apt upgrade`, for rolling-release dependency changes:

```bash
apt update
apt full-upgrade -y
```

### Check the installer log

```bash
cat ~/.termo-kali/install.log
```

### Check free storage

```bash
df -h "$HOME"
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

## 🔁 Re-run / Update

The base installer is safe to run again. If Kali is already installed, it preserves the existing rootfs and refreshes its launcher, helpers and APT source configuration:

```bash
./termo-kali.sh
```

Desktop management is separate:

```bash
./termo-kali-desktop.sh status
```

To update Termo-Kali itself:

```bash
git pull --ff-only
./termo-kali.sh --doctor
./termo-kali.sh --repair
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
