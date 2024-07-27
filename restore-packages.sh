#!/bin/bash

if [[ ! -f pacman_packages.txt ]]; then
    echo "Error: pacman_packages.txt not found!"
    exit 1
fi

if [[ ! -f aur_packages.txt ]]; then
    echo "Error: aur_packages.txt not found!"
    exit 1
fi

sudo pacman -Syu --noconfirm
sudo pacman -S --needed --noconfirm base-devel git

if ! command -v yay &> /dev/null; then
    echo "yay not found. Installing yay..."
    git clone https://aur.archlinux.org/yay.git
    cd yay
    makepkg -si --noconfirm
    cd ..
    rm -rf yay
fi

echo "Installing packages from pacman_packages.txt..."
sudo pacman -S --needed --noconfirm - < pacman_packages.txt

echo "Installing packages from aur_packages.txt..."
yay -S --needed --noconfirm - < aur_packages.txt

echo "Restoration completed."
