# STATUS: THIS IS THE TESTING BRANCH, VERY WIP

# ArtixInstaller

## Introduction
ArtixInstaller is a barebones artix linux install script, with dinit &amp; btrfs support, and a couple of personal enhancements.\
this repo will evolve over time, as I gain more knowledge on scripting, linux, and git. any feedback is much appreciated!
The branch you're currently viewing is the testing branch. As Artix Linux seems tempting again, this branch should be updated constantly, unless the repo is archived at the moment of viewing it.

## Enhancements
### implemented features:
- [ ] dinit as init system
- [ ] filesystem choice between ext4 and btrfs
- [ ] booster as replacement for mkinitcpio (faster, smaller initramfs - with grub auto-detection patch)
- [ ] custom AUR repo management with aurutils (just the very start)
### currently considering:
- [ ] dotfile syncing (optional, my personal dotfile management with chezmoi)
- [ ] tightening btrfs support with Snapper+snap-pac+grub-btrfs (should be more resilient to broken updates)
- [ ] improving btrfs mount options
- [ ] simplifying the aurutils process and guidance
- [ ] adding zramen for systemd-less zram management
- [ ] switching from sudo to doas
- [ ] add xfs to recommended filesystems
- [ ] options for different linux kernels (zen, cachyos maybe?)

## Usage
- In a VM/bare metal PC, boot the latest weekly base ISO ~~(with dinit)~~ (weekly dinit ISOs currently unavailable), and login with the following credentials: `artix` as username and password
- Once logged in, perform the following commands:
```bash
sudo su
pacman -Sy --noconfirm git
git clone https://github.com/stepharmony/ArtixInstaller --single-branch -branch testing-2026
cd ArtixInstaller/
chmod +x ./install.sh
./install.sh
```
- Follow each prompt during the setup session
- **After installation, don't forget to change your root and user password as a security measure!**
