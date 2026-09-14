# ⚡ Termo-Kali

### Kali Linux on Termux & Android — No Root Required

**Termo-Kali** is a lightweight Bash installer for setting up a Kali Linux environment on Android through **Termux** and **PRoot**. It is designed for users who want a portable Kali CLI environment without modifying or rooting their Android device.

> Simple setup • Portable environment • Termux + PRoot

[![Platform](https://img.shields.io/badge/Platform-Android-3DDC84?style=flat-square&logo=android&logoColor=white)](https://www.android.com/)
[![Termux](https://img.shields.io/badge/Termux-Supported-000000?style=flat-square&logo=terminal&logoColor=white)](https://termux.dev/)
[![Shell](https://img.shields.io/badge/Shell-Bash-4EAA25?style=flat-square&logo=gnu-bash&logoColor=white)](https://www.gnu.org/software/bash/)
[![Kali](https://img.shields.io/badge/Kali-Linux-557C94?style=flat-square&logo=kalilinux&logoColor=white)](https://www.kali.org/)
[![License](https://img.shields.io/badge/License-MIT-blue?style=flat-square)](LICENSE)

---

## ✨ Features

- 🚀 Simple Kali Linux installation from Termux
- 📦 Automatic dependency checking
- 🧩 Uses PRoot instead of requiring Android root
- 📱 Designed for Android and Termux
- 🖥️ Runs Kali from a generated `start-kali.sh` launcher
- 🛠️ Includes a small Kali command reference after installation
- ⚡ Lightweight CLI-focused setup
- 🔓 No bootloader unlocking or custom recovery required

Termo-Kali is intended for a **Kali userspace environment**, not as a replacement for Android or a full native Kali installation.

---

## 📋 Requirements

Before installing, make sure you have:

- Android device
- Termux
- Internet connection
- Sufficient free storage
- Bash-capable Termux environment

For the best compatibility, use a current Termux build from a maintained distribution source such as F-Droid or the official Termux GitHub releases.

> The Google Play Store version of Termux has historically been outdated and may not be compatible with current Termux workflows.

---

## 🚀 Installation

Open **Termux** and run:

```bash
pkg update -y && pkg upgrade -y
pkg install git -y
```

Clone the repository:

```bash
git clone https://github.com/Kaztral-ar/Termokali.git
cd Termokali
```

Make the installer executable:

```bash
chmod +x termo-kali.sh
```

Start the installation:

```bash
./termo-kali.sh
```

> **Important:** Use `bash termo-kali.sh` or `./termo-kali.sh`. Do not use `sh termo-kali.sh`, because the installer uses Bash-specific syntax.

---

## ▶️ Start Kali

After installation, start the generated Kali environment with:

```bash
~/start-kali.sh
```

Once inside Kali, verify the environment with:

```bash
cat /etc/os-release
```

You can then update the Kali package lists:

```bash
apt update
apt full-upgrade -y
```

Exit Kali with:

```bash
exit
```

---

## 🧰 Useful Commands

### Termux

```bash
# Start Kali
~/start-kali.sh

# Make the launcher executable if needed
chmod +x ~/start-kali.sh
```

### Kali

```bash
# Update packages
apt update
apt full-upgrade -y

# Install a package
apt install <package-name>

# Search for a package
apt search <package-name>

# Show Kali release information
cat /etc/os-release
```

After installation, the project also creates:

```text
kali-help.txt
```

for a quick command reference.

---

## 🧠 How It Works

Termo-Kali runs Kali in userspace rather than replacing Android:

```text
┌──────────────────────────┐
│          Android         │
├──────────────────────────┤
│          Termux          │
├──────────────────────────┤
│          PRoot           │
├──────────────────────────┤
│       Kali Linux         │
│        userspace         │
└──────────────────────────┘
```

The installer checks for required Termux packages, downloads the Kali setup script, runs the installation, and creates a launcher for starting the environment.

This is conceptually similar to the rootless approach documented by Kali NetHunter: Kali can run on an unrooted Android device, but rootless environments have limitations compared with a rooted device and dedicated kernel.

---

## ⚠️ Limitations

Because Termo-Kali uses Termux and PRoot without Android root:

- Hardware-level features are limited.
- Kernel-dependent functionality is not provided.
- Some Kali tools may have reduced functionality.
- Wireless injection and similar kernel-level capabilities are not provided by this setup.
- Performance can differ from a native Kali installation.

For the official Kali mobile options and their feature differences, see the Kali NetHunter documentation.

---

## 🔄 Updating Kali

Once Kali is running, use the normal Kali package-management workflow:

```bash
apt update
apt full-upgrade -y
```

To update Termo-Kali itself, pull the latest repository changes:

```bash
cd ~/Termokali
git pull --ff-only
```

Then run the installer again if you need to regenerate the installation:

```bash
./termo-kali.sh
```

---

## 🗑️ Uninstall

Termo-Kali's generated environment can be removed from Termux with:

```bash
rm -rf ~/kali-fs ~/kali-binds ~/start-kali.sh ~/kali-help.txt
```

Only remove these paths if they belong to your Termo-Kali installation.

This does **not** uninstall Termux itself.

---

## 🛠️ Troubleshooting

### `proot: not found`

Install PRoot in Termux:

```bash
pkg update
pkg install proot
```

Then try:

```bash
~/start-kali.sh
```

### `wget: command not found`

Install the required package:

```bash
pkg install wget
```

### Permission denied

Make the scripts executable:

```bash
chmod +x termo-kali.sh
chmod +x ~/start-kali.sh
```

### Installation fails

Update Termux packages and retry:

```bash
pkg update -y
pkg upgrade -y
pkg install git wget python openssl-tool proot -y
./termo-kali.sh
```

If the problem continues, open an issue with the exact error message and your Android/Termux environment details.

---

## 📁 Project Structure

```text
Termokali/
├── termo-kali.sh       # Main installer
├── termo.txt            # Additional setup notes
├── README.md            # Documentation
├── CONTRIBUTING.md      # Contribution guidelines
└── LICENSE              # MIT License
```

---

## 🤝 Contributing

Contributions are welcome — bug reports, testing, documentation improvements, and code changes can all help improve Termo-Kali.

Before contributing:

1. Fork the repository.
2. Create a feature branch.
3. Test your changes in Termux.
4. Keep changes focused.
5. Open a pull request with a clear description.

See [CONTRIBUTING.md](CONTRIBUTING.md) for the project contribution guidelines.

---

## 🔗 Related Projects & Documentation

- [Kali Linux Documentation](https://www.kali.org/docs/) — official Kali documentation.
- [Kali NetHunter Rootless](https://www.kali.org/docs/nethunter/nethunter-rootless/) — official rootless Kali-on-Android documentation.
- [Termux](https://termux.dev/) — terminal environment for Android.

---

## ⚖️ License

Termo-Kali is released under the **MIT License**. See [LICENSE](LICENSE) for the complete license text.

---

## ⚠️ Disclaimer

Termo-Kali is an unofficial community project. It is not affiliated with, sponsored by, or endorsed by Kali Linux, Offensive Security, Termux, or Andronix.

Use Kali Linux and its security tools only on systems, devices, and networks where you have permission to test.

---

<div align="center">

### ⚡ Termo-Kali

**Kali Linux • Termux • Android • No Root**

</div>
