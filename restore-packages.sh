#!/bin/bash

focus-text="\e[38;2;94;255;190m"
reset="\e[m"

if [[ ! -f pacman_packages.txt ]]; then
    echo "${focus-text}Error: pacman_packages.txt not found!${reset}"
    exit 1
fi

if [[ ! -f aur_packages.txt ]]; then
    echo "${focus-text}Error: aur_packages.txt not found!${reset}"
    exit 1
fi

sudo pacman -Syu
sudo pacman -S --needed base-devel git

if ! command -v yay &> /dev/null; then
    echo "${focus-text}yay not found. Installing yay...${reset}"
    git clone https://aur.archlinux.org/yay.git
    cd yay
    makepkg -si
    cd ..
    rm -rf yay
fi

echo "${focus-text}Installing packages from pacman_packages.txt...${reset}"
sudo pacman -S --needed - < pacman_packages.txt

echo "${focus-text}Installing packages from aur_packages.txt...${reset}"
yay -S --needed - < aur_packages.txt

echo "${focus-text}Restoration completed.${reset}"
