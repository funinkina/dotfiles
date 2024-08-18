#!/bin/bash

# Array of source and target files
declare -A files=(
    ["$HOME/.dotfiles/zshrc"]="$HOME/.zshrc"
    ["$HOME/.dotfiles/gitconfig"]="$HOME/.gitconfig"
    ["$HOME/.dotfiles/starship.toml"]="$HOME/.config/starship.toml"
)

# Function to create symbolic link if it doesn't already exist
create_symlink() {
    local source_file=$1
    local target_file=$2

    if [ -e "$target_file" ]; then
        echo "The file $target_file already exists. No symlink created."
    else
        ln -s "$source_file" "$target_file"
        echo "Symlink created: $target_file -> $source_file"
    fi
}

for source_file in "${!files[@]}"; do
    create_symlink "$source_file" "${files[$source_file]}"
done
