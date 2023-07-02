# ArtixInstaller

### DISCLAIMER: this script is not yet functional in a VM. once it just works, I'll update this README accordingly

## Introduction
ArtixInstaller is a barebones artix linux install script, with dinit &amp; btrfs support, and a couple of personal enhancements.\
this repo will evolve over time, as I gain more knowledge on scripting, linux, and git. any feedback is much appreciated!

## Enhancements
not all features are implemented, just the checked ones:
- [X] use `doas` instead of `sudo`
- [X] use `linux-zen` kernel for extra performance
- [ ] use `pipewire` instead of `pulseaudio` **(sort of, the packages are there)**
- [ ] add `ananicy-cpp` service for managing each process' CPU priority
- [ ] post-install script (kde wayland, zram using zramen, and possibly other enhancements such as low-latency audio)

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
- Follow the instructions presented in the setup session
