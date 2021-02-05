function pacman_install() {
    if [ -n "$1" ]; then
        pacman -Syu --noconfirm --needed $1
    fi
    if [ -n "$2" ]; then
        pacman -Syu --noconfirm --needed --asdeps $2
    fi
}

pacman_install "man nano git htop bat fd ripgrep pacman-contrib" "bash-completion"
pacman_install "sway xdg-user-dirs pulsemixer firefox mpv noto-fonts-emoji ntfs-3g firefox-i18n-ru firefox-spell-ru imv libreoffice-fresh-ru swappy ttf-font-awesome ttf-jetbrains-mono ttf-nerd-fonts-symbols" "alacritty dmenu grim mako slurp xorg-server-xwayland pulseaudio-alsa libnotify youtube-dl"
