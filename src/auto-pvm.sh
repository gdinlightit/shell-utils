#!/usr/bin/env zsh

# auto-phpbrew.zsh - Automatically switch PHP versions based on composer.json
# Similar to auto-nvm.zsh for Node.js

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to find and extract PHP version from composer.json
find_php_version() {
    local composer_path="./composer.json"
    
    if [ -f "$composer_path" ]; then
        # Extract PHP version from composer.json
        local php_version=$(cat "$composer_path" | grep '"php":' | awk -F'"' '{print $4}' | sed 's/\^//' | cut -d'.' -f1,2)
        
        if [ -n "$php_version" ]; then
            echo "$php_version"
            return 0
        fi
    fi
    
    echo ""
    return 1
}

# Function to find the installed PHP version that matches the requirement
find_matching_php() {
    local required_version="$1"
    local available_versions=$(phpbrew list | grep -v "Installed versions:" | tr -d '*+' | awk '{print $1}')
    
    for version in $available_versions; do
        local short_version=$(echo "$version" | grep -o '[0-9]\+\.[0-9]\+' | head -1)
        if [ "$short_version" = "$required_version" ]; then
            echo "$version"
            return 0
        fi
    done
    
    echo ""
    return 1
}

# Function to switch PHP version based on composer.json
load_php_version() {
    # Store the current PHP version
    local current_php_version=$(php -v | head -n 1 | awk '{print $2}' | cut -d'.' -f1,2)
    
    # Find required PHP version from composer.json
    local required_php_version=$(find_php_version)
    
    if [ -n "$required_php_version" ]; then
        # Find matching installed PHP version
        local matching_php=$(find_matching_php "$required_php_version")
        
        if [ -n "$matching_php" ]; then
            # Only switch if not already using the correct version
            if [ "$current_php_version" != "$required_php_version" ]; then
                echo "${BLUE}🔄 Cambiando a PHP ${required_php_version} para este proyecto${NC}"
                phpbrew use "$matching_php" > /dev/null
            fi
        else
            echo "${YELLOW}⚠️ El proyecto requiere PHP ${required_php_version}, pero no está instalado${NC}"
            echo "${YELLOW}Ejecuta 'phpbrew install ${required_php_version}' para instalarlo${NC}"
        fi
    elif [ -n "$(PWD=$OLDPWD find_php_version)" ]; then
        # We've moved from a directory with a PHP requirement to one without
        # Get the default PHP version
        local default_php=$(phpbrew list | grep '\*' | awk '{print $2}')
        
        if [ -n "$default_php" ] && [ "$current_php_version" != "$(echo $default_php | grep -o '[0-9]\+\.[0-9]\+' | head -1)" ]; then
            echo "${BLUE}🔄 Volviendo a PHP por defecto (${default_php})${NC}"
            phpbrew use "$default_php" > /dev/null
        fi
    fi
}

# Register the hook to be called when changing directories
autoload -U add-zsh-hook
add-zsh-hook chpwd load_php_version

# Run once when the shell starts
load_php_version