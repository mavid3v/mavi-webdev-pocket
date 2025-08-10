Here’s a **`README.md`** you can include alongside your script so users know exactly what it does, how to run it, and what it installs.

# Mavi's Web Development Pocket Script

A one-stop automated setup script to prepare an Ubuntu-based system for full-stack and Android development.  
It installs popular development tools, SDKs, and dependencies — **completely unattended**, with clean, decorated output.

---

## 📦 Features

This script will:

1. **Verify Root Access**
   - Ensures you are running as `root` or with `sudo`.

2. **Install Required Utilities**
   - Installs `curl`, `wget`, `jq`, `unzip`, and other essentials if missing.

3. **Install Development Tools**
   - **Google Chrome** (latest `.deb` from official site)
   - **Visual Studio Code** (latest `.deb` from official site)
   - **JetBrains Toolbox App** (downloads, extracts to `/opt`, runs first-time setup)
   - **Node.js** (latest LTS from NodeSource)
   - **OpenJDK & JRE** (latest from Ubuntu repos)
   - **build-essential** (compiler tools)

4. **Install MongoDB Tools**
   - **MongoDB Compass** (latest stable from MongoDB)
   - **MongoDB Shell (mongosh)** (latest stable from MongoDB)

5. **Install Flutter SDK for Android Development**
   - Downloads the **latest stable** release from Flutter’s official JSON index
   - Extracts to `/opt/flutter`
   - Prints location and reminds you to update your `PATH`

---

## 📋 Requirements

- Ubuntu 20.04+ (or Debian-based)
- Internet connection
- Root privileges (`sudo`)

---

## 🚀 Usage

```bash
# 1. Download the script
git clone htttps://github.com/mavid3v/mavi-webdev-pocket.git
cd mavi-webdev-pocket

# 2. Make it executable
chmod +x mavi-webdev-pocket.sh

# 3. Run as root or with sudo
sudo ./mavi-webdev-pocket.sh
````

---

## 📝 Notes

* **Idempotent** — The script checks if a package is already installed and skips it.
* All installations are **silent**, with clean progress messages.
* JetBrains Toolbox will be run once silently after installation to set up its environment.
* Flutter will **not** run `flutter doctor` — you'll need to do that manually.

---

## 🛠 Post-Installation Setup

1. **Add Flutter to PATH**:

   ```bash
   export PATH="/opt/flutter/bin:$PATH"
   ```

   To make it permanent:

   ```bash
   echo 'export PATH="/opt/flutter/bin:$PATH"' >> ~/.bashrc
   source ~/.bashrc
   ```

2. **Android SDK & Emulator**:
   Follow the [Flutter Android Setup Guide](https://docs.flutter.dev/get-started/install/linux/android) to install Android Studio and SDK tools.

---

## ⚠ Disclaimer

This script installs software from the internet. Always review the code before running it on your system.

---

**Happy coding,**
