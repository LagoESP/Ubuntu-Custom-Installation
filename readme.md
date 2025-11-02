# 🚀 Ubuntu Custom Installation Script

A simple shell script to automate the setup and customization of a fresh Ubuntu installation. This script sets up admin privileges, installs common development tools and applications, and applies GNOME desktop tweaks.

## 🚨 Security Warning

This script contains an option to enable **passwordless `sudo`** for your user. This is a **major security risk** and is only intended for single-user, non-critical machines (like a personal laptop or test VM) where you understand and accept the risk. Any program or script running as your user will be able to gain full root access without your permission.

**Use with caution.**

---

## 🚀 Quick Install (One-Liner)

To download and run the latest version of the script, open your terminal and paste the following command.

This command fetches the script from this repository using `curl` and pipes it directly into `bash` with `sudo` privileges, which is required for the setup.

```bash
curl -sSL [https://raw.githubusercontent.com/LagoESP/Ubuntu-Custom-Installation/main/ubuntu_setup.sh](https://raw.githubusercontent.com/LagoESP/Ubuntu-Custom-Installation/main/ubuntu_setup.sh) | sudo bash