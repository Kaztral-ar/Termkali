# ⚡ Termo-Kali

### Kali Linux on Termux & Android — No Root Required

**Termo-Kali** makes it easy to install and run a Kali Linux environment on Android using **Termux + proot**.

> Simple setup. Reliable installation. Portable Kali environment.

[![Platform](https://img.shields.io/badge/Platform-Android-3DDC84?style=flat-square&logo=android&logoColor=white)](https://www.android.com/)
[![Termux](https://img.shields.io/badge/Termux-Supported-000000?style=flat-square&logo=terminal&logoColor=white)](https://termux.dev/)
[![Shell](https://img.shields.io/badge/Shell-Bash-4EAA25?style=flat-square&logo=gnu-bash&logoColor=white)](https://www.gnu.org/software/bash/)
[![License](https://img.shields.io/badge/License-MIT-blue?style=flat-square)](LICENSE)

---

## ✨ Features

- 🚀 **Easy installation** — get started with a simple installer.
- 📦 **Automatic dependencies** — required Termux packages are checked and installed automatically.
- 🔒 **Validated downloads** — downloaded files are checked before execution.
- 🔁 **Safe to re-run** — existing installations are detected instead of being reinstalled.
- 📝 **Detailed logging** — installation activity is recorded for troubleshooting.
- 💻 **Kali Linux environment** — runs through `proot` without root access.
- 📱 **Android support** — designed specifically for Android through Termux.
- 🖥️ **XFCE4 support** — optional graphical desktop setup.
- ⚡ **Lightweight** — minimal setup and configuration.

---

## 📋 Requirements

- 📱 **Android** device
- 📲 **Termux**
- 🌐 **Stable internet connection**
- 💾 **~2 GB+ free storage**
- 🐚 **Bash**

### Termux

Use a maintained Termux distribution:

- **F-Droid** — recommended
- **GitHub Releases** — official releases

> ⚠️ The Google Play Store version of Termux is deprecated and should not be used for this project.

---

## 🚀 Quick Start

### 1. Update Termux

```bash
pkg update -y && pkg upgrade -y
```

### 2. Install Git

```bash
pkg install git -y
```

### 3. Clone Termo-Kali

```bash
git clone https://github.com/kaztral-ar/termokali.git
cd termokali
```

### 4. Run the installer

```bash
chmod +x termo-kali.sh
./termo-kali.sh
```

Or:

```bash
bash termo-kali.sh
```

> **Do not use `sh termo-kali.sh`.**  
> The installer uses Bash-specific syntax.

---

## 🔧 Installation Process

Termo-Kali automatically:

```text
┌─────────────────────────┐
│   Check Termux          │
├─────────────────────────┤
│   Check Storage         │
├─────────────────────────┤
│   Check Internet        │
├─────────────────────────┤
│   Install Dependencies  │
├─────────────────────────┤
│   Download Kali         │
├─────────────────────────┤
│   Validate Download     │
├─────────────────────────┤
│   Install Environment   │
├─────────────────────────┤
│   Create Helper Files   │
└────────────┬────────────┘
             ↓
        🚀 Launch Kali
```

Creates:

```text
~/start-kali.sh
~/kali-help.txt
~/.termo-kali/install.log
```

---

## ▶️ Start Kali

```bash
~/start-kali.sh
```

To exit Kali:

```bash
exit
```

or press:

```text
Ctrl + D
```

---

## 🖥️ Optional XFCE4 Desktop

Want a graphical Kali environment?

Additional XFCE4 setup instructions are available in:

```text
termo.txt
```

> ⚠️ Run these commands **inside Kali**, not directly in Termux.

---

## 🔁 Re-run Safely

You can run the installer again at any time:

```bash
./termo-kali.sh
```

If an existing installation is detected, Termo-Kali avoids unnecessary reinstallation.

---

## 🛠️ Troubleshooting

### Permission denied

```bash
chmod +x ~/start-kali.sh
```

### Check storage

```bash
df -h $HOME
```

### View installation log

```bash
cat ~/.termo-kali/install.log
```

Or:

```bash
less ~/.termo-kali/install.log
```

### Installer lock

If a previous installation crashed:

```bash
rm -f ~/.termo-kali/lock
```

Only remove the lock when you are certain another Termo-Kali process is not running.

---

## 🗑️ Uninstall

```bash
rm -rf ~/start-kali.sh ~/kali-* ~/.termo-kali
```

> ⚠️ Back up important files inside Kali before uninstalling.

This does **not** uninstall Termux.

---

## 📁 Project Structure

```text
termokali/
│
├── termo-kali.sh
├── termo.txt
├── README.md
├── CONTRIBUTING.md
├── CODE_OF_CONDUCT.md
└── LICENSE
```

---

## 🤝 Contributing

Contributions, bug reports, improvements, and feature requests are welcome.

See **[CONTRIBUTING.md](CONTRIBUTING.md)** for contribution guidelines.

---

## 💬 Support

Having an issue or need help?

- 🐛 **Bug:** Open an issue on GitHub.
- 💡 **Feature request:** Open an issue and describe your idea.
- ❓ **Help:** Check the troubleshooting section and installation log first.
- 🔧 **Contribution:** See `CONTRIBUTING.md`.

---

## 📜 License

Termo-Kali is licensed under the **MIT License**.

See **[LICENSE](LICENSE)** for the full license text.

---

## ⚠️ Disclaimer

Termo-Kali is an **unofficial community project**.

It is not affiliated with, sponsored by, or endorsed by **Kali Linux, Offensive Security, or Termux**.

Use Kali Linux and its tools responsibly and only on systems and networks where you have authorization.

---

<div align="center">

### ⚡ Termo-Kali

**Kali Linux • Termux • Android • No Root**

</div>
