#!/bin/bash

# Прекратить выполнение при возникновении ошибки
set -e

KEYS="ruwin_alt_sh-UTF-8"
FONT="UniCyr_8x16"

DEVICE="/dev/sda"

ROOT_PASSWORD="ask"
TIMEZONE="/usr/share/zoneinfo/Europe/Moscow"

USER="sergey"
USER_PASSWORD="$ROOT_PASSWORD"

MODULES="amdgpu"
HOOKS="base systemd autodetect modconf block keyboard sd-vconsole fsck filesystems"

LIGHT_BLUE='\033[1;34m'
NC='\033[0m'

function init() {
    print_step "init()"

    #loadkeys $KEYS
    #setfont $FONT
    #timedatectl set-ntp true
    cat /dev/null > pacman_install.log
    ask_passwords
}

function ask_passwords() {
    if [ "$ROOT_PASSWORD" == "ask" ]; then
        PASSWORD_TYPED="false"
        while [ "$PASSWORD_TYPED" != "true" ]; do
            read -sp 'Type root password: ' ROOT_PASSWORD
            echo ""
            read -sp 'Retype root password: ' ROOT_PASSWORD_RETYPE
            echo ""
            if [ "$ROOT_PASSWORD" == "$ROOT_PASSWORD_RETYPE" ]; then
                PASSWORD_TYPED="true"
            else
                echo "Root password don't match. Please, type again."
            fi
        done
    fi

    if [ "$USER_PASSWORD" == "ask" ]; then
        PASSWORD_TYPED="false"
        while [ "$PASSWORD_TYPED" != "true" ]; do
            read -sp 'Type user password: ' USER_PASSWORD
            echo ""
            read -sp 'Retype user password: ' USER_PASSWORD_RETYPE
            echo ""
            if [ "$USER_PASSWORD" == "$USER_PASSWORD_RETYPE" ]; then
                PASSWORD_TYPED="true"
            else
                echo "User password don't match. Please, type again."
            fi
        done
    fi
}

function partition() {
    print_step "partition()"

    sfdisk -w always -W always $DEVICE < sda.sfdisk

    mkfs.fat -F32 ${DEVICE}1     # esp
    mkswap ${DEVICE}2            # swap
    mkfs.ext4 ${DEVICE}3         # root
    mkfs.ext4 ${DEVICE}4         # home

    swapon /dev/sda2
    mount /dev/sda3 /mnt
    mkdir /mnt/boot /mnt/home
    mount /dev/sda1 /mnt/boot
    mount /dev/sda4 /mnt/home
}

function install_base() {
    print_step "install_base()"

    echo 'Server = https://mirror.yandex.ru/archlinux/$repo/os/$arch' > /etc/pacman.d/mirrorlist
    echo 'Server = http://mirror.yandex.ru/archlinux/$repo/os/$arch' >> /etc/pacman.d/mirrorlist

    pacstrap -c /mnt base base-devel linux-lts linux-firmware amd-ucode openssh
}

function configuration() {
    print_step "configuration()"

    #genfstab -U /mnt >> /mnt/etc/fstab

    #tar xf configs.tar.xz
    for i in $(find configs ! -type d -printf "%P "); do
        install -D -m644 "configs/$i" "/mnt/$i";
    done

    arch-chroot /mnt sed -i 's/#Color/Color/' /etc/pacman.conf
    #arch-chroot /mnt sed -i 's/# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/' /etc/sudoers

    arch-chroot /mnt ln -s -f $TIMEZONE /etc/localtime
    arch-chroot /mnt hwclock --systohc

    arch-chroot /mnt locale-gen

    echo "root:$USER_PASSWORD" | arch-chroot /mnt chpasswd

    arch-chroot /mnt systemctl enable fstrim.timer
    arch-chroot /mnt systemctl enable sshd
}

function mkinitcpio_configuration() {
    print_step "mkinitcpio_configuration()"

    arch-chroot /mnt sed -i "s/^MODULES=()/MODULES=($MODULES)/" /etc/mkinitcpio.conf
    arch-chroot /mnt sed -i "s/^HOOKS=(.*)$/HOOKS=($HOOKS)/" /etc/mkinitcpio.conf
    arch-chroot /mnt mkinitcpio -P > mkinitcpio.log
}

function network() {
    print_step "network()"

    arch-chroot /mnt systemctl enable systemd-networkd
    arch-chroot /mnt systemctl enable systemd-resolved
}

function user() {
    print_step "user()"

    arch-chroot /mnt useradd -m -G wheel,optical,storage,log,systemd-journal -s /bin/bash $USER
    echo "$USER:$USER_PASSWORD" | arch-chroot /mnt chpasswd

    arch-chroot /mnt sed -i 's|# %wheel ALL=(ALL) ALL|%wheel ALL=(ALL) ALL|' /etc/sudoers
    arch-chroot /mnt sed -i '|# %wheel ALL=(ALL) ALL|a %wheel ALL=(ALL) NOPASSWD: /usr/bin/pacman|' /etc/sudoers
}

function bootloader() {
    print_step "bootloader()"

    arch-chroot /mnt bootctl install
}

function packages() {
    print_step "packages()"

    pacman_install "man nano git htop bat ripgrep pacman-contrib" "bash-completion"
}


function desktop_environment() {
    print_step "desktop_environment()"

    pacman_install "sway" "alacritty dmenu grim mako slurp xorg-server-xwayland"
    pacman_install "xdg-user-dirs"
    pacman_install "pulsemixer" "pulseaudio-alsa"
    pacman_install "firefox" "libnotify"
    pacman_install "mpv" "youtube-dl"
}

function display_driver() {
    print_step "display_driver()"

    pacman_install "" "vulkan-radeon libva-mesa-driver"
}

function pacman_install() {
    if [ -n "$1" ]; then
        arch-chroot /mnt pacman -Syu --noconfirm --needed $1 >> pacman_install.log
    fi
    if [ -n "$2" ]; then
        arch-chroot /mnt pacman -Syu --noconfirm --needed --asdeps $2 >> pacman_install.log
    fi
}

function packages_aur() {
    print_step "packages_aur()"

    arch-chroot /mnt bash -c 'cd /home/sergey && sudo -u sergey git clone https://aur.archlinux.org/paru.git && (cd paru && sudo -u sergey makepkg -si --noconfirm) && rm -rf paru'
    arch-chroot /mnt 
}

function end() {
    print_step "end()"

    umount -R /mnt
}

function print_step() {
    STEP="$1"
    echo ""
    echo -e "${LIGHT_BLUE}# ${STEP} step${NC}"
    echo ""
}


function main() {
    init
    partition
    install_base
    configuration
    mkinitcpio_configuration
    network
    user
    bootloader
    packages
    desktop_environment
    display_driver
    packages_aur
    end
}

main $@

# ссылки
# https://wiki.archlinux.org/index.php/Improving_performance#Reduce_disk_reads/writes
# https://wiki.archlinux.org/index.php/AMDGPU
