#!/bin/bash

if [[ ! -f packages.txt ]]; then
    echo "Error: pacman_packages.txt not found!"
    exit 1
fi

if [[ ! -f aur_packages.txt ]]; then
    echo "Error: aur-packages.txt not found!"
    exit 1
fi

sudo pacman -Syu
sudo pacman -S --needed base-devel git

if ! command -v yay &> /dev/null; then
    echo "yay not found. Installing yay..."
    git clone https://aur.archlinux.org/yay.git
    cd yay
    makepkg -si
    cd ..
    rm -rf yay
fi

echo "Installing packages from pacman_packages.txt..."
sudo pacman -S --needed - < pacman_packages.txt

echo "Installing packages from aur_packages.txt..."
yay -S --needed - < aur_packages.txt

echo "Restoration completed."
