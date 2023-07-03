# ArtixInstaller

### STATUS: this script works both in a VM and on bare metal. the installation is very minimal, you're on your own installing a DE/WM of your choice.

## Introduction
ArtixInstaller is a barebones artix linux install script, with dinit &amp; btrfs support, and a couple of personal enhancements.\
this repo will evolve over time, as I gain more knowledge on scripting, linux, and git. any feedback is much appreciated!

## Enhancements
not all features are implemented yet (they will be over time), just the checked ones:
- [X] use `doas` instead of `sudo`
- [X] use `linux-zen` kernel for extra performance
- [ ] use `pipewire` instead of `pulseaudio` **(sort of, the packages are there)**
- [ ] add `ananicy-cpp` service for managing each process' CPU priority
- post-install script
  - [ ] KDE on Wayland (NVIDIA/AMD)
  - [ ] faster swap with zram, using zramen service
  - [ ] low-latency audio settings using pipewire

## Usage
- In a VM/bare metal PC, boot the latest weekly base ISO (with dinit), and login with the following credentials: `artix` as username and password
- Once logged in, perform the following commands:
```bash
sudo su
pacman -Sy --noconfirm git
git clone https://github.com/stepharmony/ArtixInstaller
cd ArtixInstaller/
chmod +x ./install.sh
./install.sh
```
- Follow each prompt during the setup session
- **After installation, don't forget to change your root and user password as a security measure!**
