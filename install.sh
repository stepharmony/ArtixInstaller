#!/bin/bash
#
#     ___         __  _      ____           __        ____
#    /   |  _____/ /_(_)  __/  _/___  _____/ /_____ _/ / /__  _____
#   / /| | / ___/ __/ / |/_// // __ \/ ___/ __/ __ `/ / / _ \/ ___/
#  / ___ |/ /  / /_/ />  <_/ // / / (__  ) /_/ /_/ / / /  __/ /
# /_/  |_/_/   \__/_/_/|_/___/_/ /_/____/\__/\__,_/_/_/\___/_/
#

# exit on any error, exit on unset variables, and propagate exit codes through pipes
set -euo pipefail

# logging setup
LOG_FILE="/tmp/artix-install-$(date +%Y-%m-%d_%H-%M-%S).log"


# variables and functions for printing
red="\e[31m"; 
green="\e[32m"; 
yellow="\e[33m";
cyan="\e[36m" 
reset="\e[39m"
upone="\e[1A"; 
delline="\e[2K"; 
oneup="\r${upone}${delline}${upone}"

if [[ "$(id -u)" -ne 0 ]]; then
    echo -e "${red}this script must be run as root. re-executing with sudo...${reset}"
    sleep 0.5
    exec sudo "$0" "$@"
fi

exec 3>&1
exec &>"$LOG_FILE"

printyellow() 
{ 
    echo -e "$1"
    echo -e "${yellow}${1}${reset}" >&3
}
printred() 
{  
    echo -e "$1"
    echo -e "${red}${1}${reset}" >&3
}
printgreen() 
{  
    echo -e "$1"
    echo -e "${green}${1}${reset}" >&3
}

newline() { 
    echo -e ""
    echo -e "" >&3
}


finish() {
    exit_code=$?
    umount -R /mnt 2>/dev/null || true
    if [ "${exit_code}" -eq 0 ]; then
        printgreen "\n--- SCRIPT FINISHED SUCCESSFULLY ---"
        printyellow "full log file is available at: ${LOG_FILE}"
        printyellow "view using 'less -R ${LOG_FILE}'"
        printgreen "you may now reboot the system."
    elif [ "${exit_code}" -ne 1 ]; then    
        printred "\n--- SCRIPT FAILED ---"
        printred "an error occurred (exit code: $exit_code). the system state may be incomplete."
        printyellow "showing last 20 lines of the log:"
        tail -n 20 "$LOG_FILE" >&3
        printyellow "full log file is available at: ${LOG_FILE}"
        printyellow "view using 'less -R ${LOG_FILE}'"    
    fi
}

handle_exit() {
    finish
}

handle_abort() {
    echo "" >&3
    printred "script aborted by user"
    exit 1
}
trap handle_exit EXIT
trap handle_abort INT TERM

# announce logging
clear >&3
printyellow "ArtixInstaller-v1.0.0 by stepharmony"
printyellow "logging all output to: ${LOG_FILE}"
newline

# detecting stuff
cpu_vendor=$(lscpu | grep "Vendor ID:" | awk '{print $NF}')
ucode="intel-ucode"
if [[ ${cpu_vendor} == *"AuthenticAMD"* ]]; then ucode="amd-ucode"; fi
gpu_vendor=$(lspci | grep -i "vga" | awk '{print $5}')
boot="BIOS"
if [[ -d /sys/firmware/efi/efivars ]]; then boot="UEFI"; fi

# ask questions
choosedisk()
{
    printyellow "available disks:"
    lsblk -n --output TYPE,KNAME,MODEL,SIZE | awk '$1=="disk"{print "  "$2, $3, $4}' >&3
    printyellow "choose the disk name (e.g., sda)"

    while true; do
        read -r -p "(*): " disk 2>&3
        if [[ -b "/dev/$disk" ]];  then
            break
        else
            printf "%s" "${oneup}"; newline
            printred "invalid selection. please enter a valid disk name."
        fi
    done

    diskdir="/dev/$disk"
    efipart="${diskdir}1"; 
    rootpart="${diskdir}2"
    if [[ $disk == *"nvme"* ]]; then efipart="${diskdir}p1"; rootpart="${diskdir}p2"; fi
}

choosefilesystem()
{
    printyellow "choose a filesystem: [1] ext4 (default), [2] btrfs (no snapper)"
    read -r -p "(*): " -n 1 fs_choice 2>&3; newline
    filesystem="ext4"
    if [[ "$fs_choice" == "2" ]]; then filesystem="btrfs"; fi
    printgreen "selected filesystem: ${filesystem}"
}

choosedisplayserver()
{
    printyellow "choose a display server: [1] Xorg (recommended), [2] XLibre (fixes from master branch & more)"
    read -r -p "(*): " -n 1 ds_choice 2>&3; newline
    displayserver="xorg"
    display_server_pkgs=("xorg" "xorg-drivers")
    if [[ "$ds_choice" == "2" ]]; then
        displayserver="xlibre"
        display_server_pkgs=("xlibre" "xlibre-drivers")
    fi
    printgreen "selected display server: ${displayserver}"
}

userdetails()
{
    read -r -p "username: " username 2>&3
    read -r -p "hostname: " hostname 2>&3
    read -r -s -p "root password: " rootpass 2>&3; newline
    while true; do
        read -r -s -p "user password for '${username}': " userpass 2>&3; newline
        read -r -s -p "confirm user password: " userpass_confirm 2>&3; newline

        if [[ -z "$userpass" ]]; then
            printred "password cannot be empty. please try again."
            continue
        fi
        if [[ "$userpass" == "$userpass_confirm" ]]; then
            break
        else
            printred "passwords do not match. please try again."
        fi
    done
}

asktimezone()
{
    printyellow "enter your timezone (e.g. Europe/London, America/New_York)"

    while true; do
        read -r -p "(*): " timezone 2>&3
        if [[ -f "/usr/share/zoneinfo/${timezone}" ]]; then
            break
        else
            printf "%s" "${oneup}"; newline;
            printred "invalid timezone. please use the 'Region/City' format."
        fi
    done

    printgreen "selected timezone: ${timezone}"
}

askpostinstall()
{
    printyellow "want to apply the post-config script after install? (y/N)"
    read -r -p "(*): " -n 1 postinstall_choice 2>&3; newline;
    if [[ "$postinstall_choice" =~ ^[Yy]$ ]]; then
        printyellow "the script will be executed when opening GNOME terminal"
        printyellow "for the first time after rebooting into Cinnamon"
        printyellow "if you wish to execute it again, type /usr/bin/post-install.sh in the terminal'"
        # post-install changes here, adding them after creating the post-install script.
    fi
}

executeinstall()
{
    # partitioning, formatting, and mounting
    if ! command -v sgdisk &> /dev/null; then
        printyellow "-> gptfdisk not found, installing..."
        pacman -Sy --noconfirm gptfdisk 
    fi
    printyellow "-> partitioning and mounting filesystems..."
    sgdisk --zap-all "${diskdir}"
    sgdisk -n 1:0:+512M -t 1:ef00 -c 1:"EFI" "${diskdir}"
    sgdisk -n 2:0:0   -t 2:8300 -c 2:"ROOT" "${diskdir}"
    mkfs.vfat -F32 -n "EFI" "${efipart}"
    if [[ ${filesystem} == "ext4" ]]; then
        mkfs.ext4 -L "ROOT" -F "${rootpart}"
        mount "${rootpart}" /mnt
        mkdir -p /mnt/boot/efi
    else # btrfs
        mkfs.btrfs -L "ROOT" -f "${rootpart}"
        mount "${rootpart}" /mnt
        for subvol in @ @home @log @snapshots; do btrfs sub create "/mnt/${subvol}"; done
        umount /mnt
        mount -o "defaults,noatime,compress=zstd,ssd,subvol=@" "${rootpart}" /mnt
        mkdir -p /mnt/{boot/efi,home,var/log,.snapshots}
        mount -o "defaults,noatime,compress=zstd,ssd,subvol=@home" "${rootpart}" /mnt/home
        mount -o "defaults,noatime,compress=zstd,ssd,subvol=@log" "${rootpart}" /mnt/var/log
        mount -o "defaults,noatime,compress=zstd,ssd,subvol=@snapshots" "${rootpart}" /mnt/.snapshots
    fi
    mount "${efipart}" /mnt/boot/efi

    # pacman configuration & basestrap
    printyellow "-> configuring pacman and installing base system... (might take a long time depending on internet speed)"
    sed -i 's/^#ParallelDownloads.*/ParallelDownloads = 10/' /etc/pacman.conf
    sed -i 's/^#Color/Color\nILoveCandy/' /etc/pacman.conf
    local fs_progs_pkg
    if [[ "${filesystem}" == "ext4" ]]; then
        fs_progs_pkg="e2fsprogs"
    else
        fs_progs_pkg="${filesystem}-progs"
    fi
    local packages=(
        "base" "base-devel" "dinit" "elogind-dinit" "sudo" "${ucode}"
        "booster" "grub" "os-prober" "efibootmgr" "gdisk" "pacman-contrib"
        "linux" "linux-headers" "linux-firmware"
        "${fs_progs_pkg}" "dosfstools" "ntfs-3g" "nano" "git" "wget"
        "networkmanager-dinit" "dhcpcd-dinit"
        "pipewire-dinit" "pipewire-alsa" "pipewire-jack" "pipewire-pulse-dinit" "wireplumber-dinit"
        "cinnamon" "xdg-user-dirs" "dbus-dinit" "lightdm-dinit" "lightdm-gtk-greeter" "${display_server_pkgs[@]}"
        "gnome-terminal" "firefox"
    )
    
    # add NVIDIA packages if detected
    if [[ "${gpu_vendor}" == "NVIDIA" ]]; then
        printyellow "-> NVIDIA GPU detected. adding proprietary drivers to basestrap..."
        packages+=("nvidia" "nvidia-utils-dinit" "nvidia-settings")
    fi

    # some nice output of the packages installed, cause why not :D
    stdbuf -oL basestrap /mnt "${packages[@]}" --ignore mkinitcpio 2>&1 | \
        grep --line-buffered -E '^(installing)' | \
        while read -r line; do
            printyellow "--> $line"
        done
    fstabgen -U /mnt >> /mnt/etc/fstab

    # chroot and final configuration
    printyellow "-> entering chroot and finalizing installation... (this may take a moment)"
    export timezone hostname rootpass userpass username gpu_vendor displayserver postinstall_choice
    artix-chroot /mnt /bin/bash 3>&3 <<'EOF'
set -euo pipefail

# system setup -- time, locale & hostname
echo "-> configuring time, locale & hostname..." >&3
ln -sf "/usr/share/zoneinfo/${timezone}" /etc/localtime
hwclock --systohc
echo "en_US.UTF-8 UTF-8" > /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf
echo "${hostname}" > /etc/hostname
echo -e "127.0.0.1\tlocalhost\n::1\t\tlocalhost\n127.0.1.1\t${hostname}.localdomain\t${hostname}" >> /etc/hosts

# pacman configuration in chroot
echo "-> configuring sensible pacman settings (i.e. ParallelDownloads, color, VerbosePkgLists)..." >&3
sed -i 's/^#ParallelDownloads.*/ParallelDownloads = 10/' /etc/pacman.conf
sed -i 's/^#Color/Color\nILoveCandy/' /etc/pacman.conf
sed -i 's/^#VerbosePkgLists/VerbosePkgLists/' /etc/pacman.conf
echo "--> configuring pacman to ignore mkinitcpio..." >&3
sed -i 's/^#IgnorePkg   =/IgnorePkg   = mkinitcpio gnome-backgrounds/' /etc/pacman.conf

# user and privileges setup
echo "root:${rootpass}" | chpasswd
useradd -m -G wheel,audio,video -s /bin/bash "${username}"
echo "${username}:${userpass}" | chpasswd

echo "%wheel ALL=(ALL) ALL" > /etc/sudoers.d/wheel
chmod 0440 /etc/sudoers.d/wheel

echo "-> creating standard XDG user directories for ${username}..." >&3
sudo -u "${username}" xdg-user-dirs-update

# enabling boot services
echo "-> enabling necessary boot services..." >&3
boot_services=("NetworkManager" "lightdm" "dhcpcd" "elogind")
for service in "${boot_services[@]}"; do    
    echo "--> enabling service: ${service}" >&3
    ln -sf "/etc/dinit.d/${service}" "/etc/dinit.d/boot.d"
done

# enabling user services
# dinit-user-spawn just got merged into dinit a few days ago,
# making the activation of user services trivial (compared to turnstile-dinit)
# forum post: https://forum.artixlinux.org/index.php/topic,8537.0.html
echo "-> pre-enabling user services for ${username}..." >&3
USER_SERVICE_DIR="/home/${username}/.config/dinit.d/boot.d"
sudo -u "${username}" mkdir -p "${USER_SERVICE_DIR}"

user_services=("dbus" "pipewire" "pipewire-pulse" "wireplumber")

# the source for user services is typically in /etc/dinit.d/user/
# it's now easier than ever to setup audio on artix :D
# normally you'd do 'dinitctl enable pipewire' but we're in chroot environment
for service in "${user_services[@]}"; do 
    echo "--> enabling user service ${service}" >&3
    sudo -u "${username}" ln -s "/etc/dinit.d/user/${service}" "${USER_SERVICE_DIR}/"
done

# nvidia settings
if [[ "${gpu_vendor}" == "NVIDIA" ]]; then
    echo "-> NVIDIA detected, applying needed changes..." >&3
    echo "--> configuring early KMS start w/ booster..." >&3
    echo "modules_force_load: nvidia,nvidia_modeset,nvidia_uvm,nvidia_drm" > /etc/booster.yaml
    # NVIDIA/XLibre compatibility fix
    if [[ "${displayserver}" == "xlibre" ]]; then
        echo "--> fixing NVIDIA+XLibre compatibility..." >&3
        mkdir -p /etc/X11/xorg.conf.d
        echo -e 'Section "ServerFlags"\n\tOption "IgnoreABI" "true"\nEndSection' > /etc/X11/xorg.conf.d/xlibre.conf
    fi
fi


# bootloader and initramfs
echo "-> configuring bootloader and initramfs..." >&3
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=Artix --recheck

echo "--> patching /etc/grub.d/10_linux to detect booster by default..." >&3
sed -i 's/"initrd-\${version}\.gz" \\/"initrd-\${version}.gz" "booster-\${version}.img" \\/' /etc/grub.d/10_linux


echo "--> regenerating GRUB config..." >&3
grub-mkconfig -o /boot/grub/grub.cfg
echo "--> rebuilding initramfs with booster..." >&3
/usr/lib/booster/regenerate_images


EOF
}

verifydetails()
{
    clear >&3
    printyellow "VERIFY INSTALLATION PLAN"
    printyellow "disk: ${green}/dev/${disk}"
    printyellow "filesystem: ${green}${filesystem}"
    printyellow "display server: ${green}${displayserver}"
    printyellow "timezone: ${green}${timezone}"
    printyellow "username: ${cyan}${username}"
    printyellow "hostname: ${green}${hostname}"
    newline
    printyellow "ADDITIONAL INFO"
    printyellow "cpu vendor: ${green}${cpu_vendor}"
    printyellow "gpu vendor: ${green}${gpu_vendor}"
    newline
    printyellow "do you want to proceed? this will ERASE ${diskdir}. (y/N)"
    read -r -p "(*): " -n 1 installchoice 2>&3; newline;
    if [[ "$installchoice" =~ ^[Yy]$ ]]; then
        clear >&3
        printyellow "INSTALLING ARTIX LINUX"
        executeinstall
    else
        printred "installation aborted."
        exit 1
    fi
}

# main execution. UEFI only, for now
if [[ ${boot} == "BIOS" ]]; then printred "system runs in legacy BIOS mode. aborting." && exit 1; fi

choosedisk
choosefilesystem
choosedisplayserver
asktimezone
askpostinstall
userdetails
verifydetails
