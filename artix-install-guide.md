# preliminary info
this guide will be less verbose than the gentoo install guide, and it will be just for my personal use. it's also meant to track changes to later add in my artix install script. the guide is very WIP, but the final goal will be:
- [x] dinit as the bootsystem ✅ 2026-03-29
- [x] limine as bootloader ✅ 2026-03-29
	- GRUB will be used for the time being for simplicity, will be replaced with limine as the guide progresses
	- the guide also assumes you have an UEFI system!!
- [x] booster as a lightweight initramfs ✅ 2026-03-29
- [x] linux-zen as kernel (cachyos kernel is too cumbersome to setup unfortunately, unless you're willing to build it on your own machine) ✅ 2026-03-29
- btrfs as the main filesystem, with snapper support
- [ ] kde plasma as the main DE, with niri as main WM
	- there will be additional steps for niri, to ensure compatibility with dinit
- [ ] nvidia driver shenanigans supported

**NOTE:** the final goal is only a roadmap for what I want this guide to become. in the beginning, some steps will be simplified a lot, and other programs will be used, in order to ensure a working system way ahead of implementing the goals.
**NOTE:** I advise following this guide from an Artix weekly live ISO with Plasma desktop and dinit. besides the fact that you can more easily copy-paste commands (especially the ones that are harder to type), you will have access to newer packages and less trouble caused by an older keyring. if you choose an ISO with another init system, you will need to use the service command the init system comes with, in order to enable the NTP daemon.
# installation
## set keyboard layout
only needed if you wanna use other layouts than `us`. link: [Set the keyboard layout](https://wiki.artixlinux.org/Main/Installation#Set_the_keyboard_layout)
## partitioning
easiest TUI way to manage partitions is through
```
cfdisk /dev/nvme0n1
```
or `/dev/sda` or `/dev/vda`.
my partition setup of choice will be:
- one 1GB (or 4GB if using limine snapshots) partition, type: EFI System
- a second partition covering the rest of the disk space, type: Linux filesystem
- a swap partition will not be made, in favor for either swapfile (+zswap) or zram, depending on whether you wanna hibernate or not

if you want an one-liner:
```
printf "label: gpt\n,1G,U\n,,L\n" | sfdisk /dev/sdX
```

format the partitions accordingly:
```
mkfs.vfat -F 32 /dev/nvme0n1p1 && fatlabel /dev/nvme0n1p1 ESP
mkfs.xfs -f -L root /dev/nvme0n1p2
```

time to mount partitions:
```
mount /dev/disk/by-label/root /mnt
mkdir -p /mnt/boot
mount /dev/disk/by-label/ESP /mnt/boot
```
## checking internet connection
just pinging the artix website should be enough:
```
ping artixlinux.org -c 3
```
continue to `installing the base system` if the pings went through!
if the pings didn't go through, you will need to configure the internet connection, here are a few programs you can use:
- dhcpcd (for ethernet)
- alternatives for wifi connections:
	- connman (included in live iso)
	- iw (through iwctl)
	- wpa_supplicant (supports WPA/WPA2)
### updating the system clock
for a hassle-free installation, activate the NTP daemon using one of the init system commands, depending on which ISO you have downloaded:

for dinit:
```
dinitctl start ntpd
```
for openrc:
```
rc-service ntpd start
```
for s6:
```
s6-rc -u change openntpd
```
for runit:
```
sv up openntpd
```
## installing the base system
a minimal working system can be achieved with
```
basestrap /mnt base base-devel dinit elogind-dinit dbus-dinit booster nano fastfetch
```
(ofc instead of `nano` you can use `neovim`)
### installing the kernel
```
basestrap /mnt linux-zen linux-firmware
```
**NOTE:** if you have a newer Intel CPU, make sure to also basestrap the `sof-firmware` package!
### installing the microcode
**NOTE:** this section is automated if you're using my artix install script, as with a lot of other things!
whether you're using an Intel or AMD CPU, I recommend also basestrapping the microcode for your appropriate CPU, like this:
- `intel-ucode` - if you're using an Intel CPU
- `amd-ucode` if you're using an AMD CPU
### preparing the chroot environment
generating the fstab on other distros is cumbersome, but on artix it's very simple!
```
fstabgen -U /mnt >> /mnt/etc/fstab
```
be sure to check the fstab file for any mistakes. you can either manually edit it or unmount everything and re-mount.

after you checked the fstab file, you must chroot into the system:
```
artix-chroot /mnt
```
## configuring the base system
### timezone and localization
setting a timezone is very recommended. be sure to navigate through `/usr/share/zoneinfo` until you get to your timezone. I will be using `Europe/Vienna` as an example:
```
ln -sf /usr/share/zoneinfo/Europe/Vienna /etc/localtime && hwclock --systohc
```
speaking of timezones, installing a NTP daemon makes time synchronization pretty much hassle-free, and I recommend using `chrony` over `ntpd`, because it's more accurate and modern. you will have to install it and the enable the `chronyd` service on boot:
```
pacman -S chrony-dinit
ln -sf "/etc/dinit.d/chronyd" "/etc/dinit.d/boot.d/"
```


localization is also important, and affects how many programs interpret your region. edit the `/etc/locale.gen` file by uncommenting the locale you wish to use.
generate the locales using:
```
locale-gen
```
you can set the locale system-wide by creating and editing `/etc/locale.conf` with the following:
```
LANG="en_US.UTF-8"  <-- replace with your main locale!
LC_COLLATE="C"
```
here's an one-liner if you prefer that instead:
```
printf "LANG=en_US.UTF-8\nLC_COLLATE=C\n" > /etc/locale.conf
```
### bootloader (Limine)
> [!warning] WIP notice
> while Limine has been tested to work in a VM (and bare-metal), this section is not yet complete. I need to add the corresponding limine hooks, as well as the option to boot to snapper snapshots through limine. the latter will influence the partitioning very early on, because the snapshot method requires a >4GB EFI partition.

install limine and efibootmgr (important for making the boot entry):
```
pacman -S limine efibootmgr
```
we will then need to manually copy Limine's .EFI file to the actual ESP partition, and then make a boot entry so that our BIOS can detect it:
```
mkdir -p /boot/EFI/artix-limine
cp /usr/share/limine/BOOTX64.efi /boot/EFI/artix-limine/
efibootmgr --create --disk /dev/nvme0n1 --part 1 --label "Artix Limine" --loader '\EFI\artix-limine\BOOTX64.EFI' --unicode
```
all that's left is to make the limine configuration. for the time being, it will be very barebones. as I gain more knowledge about how Limine works and how I can leverage it for the guide's goals, this section will be refined.

Limine doesn't make config files by default (like GRUB), but making a config file isn't complicated at all. make a new file with `nano /boot/EFI/artix-limine/limine.conf` and add the following:
```
timeout: 3

/Artix (Zen, booster initramfs)
    protocol: linux
    path: boot():/vmlinuz-linux-zen
    cmdline: root=LABEL=root rw quiet
    module_path: boot():/booster-linux-zen.img
```
if you decided to add the CPU microcode, for example for your AMD CPU, you should add another `module_path` line before the `booster-linux-zen` one, like this:
```
    module_path: boot():/amd-ucode.img
```
replace with `intel-ucode` if you're using an Intel CPU instead.

a good QoL-addition is to setup a pacman hook which automates copying Limine to the EFI partition whenever it's updated through `pacman`.

make a new file using `nano /etc/pacman.d/hooks/99-limine.conf` and add the following:
```
[Trigger]
Operation = Install
Operation = Upgrade
Type = Package
Target = limine              

[Action]
Description = Deploying Limine after upgrade...
When = PostTransaction
Exec = /usr/bin/cp /usr/share/limine/BOOTX64.EFI /boot/EFI/artix-limine/
```
### bootloader (GRUB)
however, if you prefer GRUB, you can still use it! install grub and os-prober:
```
pacman -S grub os-prober efibootmgr
```
to install the grub bootloader:
```
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=Artix --recheck
```
because we chose to use booster as our initramfs generator (instead of mkinitcpio), GRUB still won't boot using booster without going to advanced options, unless we patch the grub.d file like so:
```
sed -i 's/"initrd-\${version}\.gz" \\/"initrd-\${version}.gz" "booster-\${version}.img" \\/' /etc/grub.d/10_linux
# I highly recommend just copy-pasting the command if possible
```
now, it's recommended to regenerate the GRUB config and initramfs (using booster):
```
grub-mkconfig -o /boot/grub/grub.cfg
/usr/lib/booster/regenerate_images
```
### user and network management
before following the steps, think of an username for the regular user, as well as the hostname. some steps will be simplified if you export them as temp environment variables. the guide will use the following:
```
export MYUSER="cloak"
export MYHOST="artix-btw"
```
firstly set the root password with
```
passwd
```
then, create a regular user (example: `cloak`) and set its password:
```
useradd -m -G audio,video,wheel $MYUSER
passwd $MYUSER
```
by default, the user can't escalate to root when needed using `sudo`. we need to manually enable that function for users in the `wheel` group (which we have added our regular user to):
```
echo "%wheel ALL=(ALL) ALL" > /etc/sudoers.d/wheel
chmod 0440 /etc/sudoers.d/wheel
```
now, create the hostname file, we'll use `artix-btw` as the hostname:
```
echo "$MYHOST" > /etc/hostname
```
besides creating the hostname, we'll have to update `/etc/hosts`. with that in mind, we should add the following to `/etc/hosts`:
```
127.0.1.1  artix-btw.localdomain artix-btw # ADD HOSTNAME MANUALLY!
```
or this lazy one-liner:
```
printf "127.0.1.1\t$MYHOST.localdomain $MYHOST" >> /etc/hosts
```

**NOTE:** when I last installed in the VM, the first localhost lines were already added to the hosts file. check for the following:
```
127.0.0.1  localhost
::1        localhost
```
if not, add them **before** the `127.0.1.1` line defining the hostname.

you can either install NetworkManager (if you also have wifi connections) or dhcpcd if all you have is ethernet and want something lightweight.

steps for NetworkManager:
```
pacman -S networkmanager-dinit
ln -sf "/etc/dinit.d/NetworkManager" "/etc/dinit.d/boot.d"
```
steps for dhcpcd:
```
pacman -S dhcpcd-dinit
ln -sf "/etc/dinit.d/dhcpcd" "/etc/dinit.d/boot.d"
```
### user service stuff
we will make use of `dinit-user-spawn` instead of `turnstile` at this stage, because it's much simpler to maintain. hopefully we won't have to use `turnstile` when setting up niri.
if you want to use a desktop environment, it's a good idea to enable dbus and pipewire services, as the regular user.
if you haven't installed dbus, elogind and pipewire already, now it's a good idea to do so!
```
pacman -S --noconfirm dinit-user-spawn dbus-dinit elogind-dinit pipewire-dinit pipewire-pulse-dinit pipewire-alsa pipewire-jack wireplumber-dinit
```

now that you have installed dbus and pipewire, activating them as an user service becomes trivial:
```bash
# 1. Define the user (if not already set)
export MYUSER="cloak"

# 2. Create the directory (as root, we'll fix permissions later)
mkdir -p /home/$MYUSER/.config/dinit.d/boot.d

# 3. Manually create the symlink for elogind and dinit-user-spawn
ln -sf "/etc/dinit.d/elogind" "/etc/dinit.d/boot.d"
ln -sf "/lib/dinit.d/dinit-user-spawn" "/etc/dinit.d/boot.d"

# 4. Manually create the symlinks for user services
ln -s /etc/dinit.d/user/dbus /home/$MYUSER/.config/dinit.d/boot.d/
ln -s /etc/dinit.d/user/pipewire /home/$MYUSER/.config/dinit.d/boot.d/
ln -s /etc/dinit.d/user/pipewire-pulse /home/$MYUSER/.config/dinit.d/boot.d/
ln -s /etc/dinit.d/user/wireplumber /home/$MYUSER/.config/dinit.d/boot.d/

# 5. Fix permissions so the user actually owns these files
chown -R $MYUSER:$MYUSER /home/$MYUSER/.config
```
# configuring the system
now that everything's done, we can restart the PC, like so:
```
exit # exits the chroot environment
umount -R /mnt # unmounts everything, safe
reboot
```

from now onwards, we're going to further configure the system to include nice stuff such as a desktop environment (or window manager), display manager and some other goodies.

