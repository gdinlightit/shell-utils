#!/usr/bin/env zsh

# Enhanced auto-phpbrew.zsh - Automatically switch PHP versions based on composer.json
# With added features for installation and permission fixing

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Verify phpbrew is installed
if ! command -v phpbrew &> /dev/null; then
    echo -e "${RED}❌ PHPBrew no está instalado.${NC}"
    echo -e "${YELLOW}Para instalar PHPBrew, visita: https://github.com/phpbrew/phpbrew${NC}"
    return 1
fi

# Function to fix phpbrew permissions issue
fix_phpbrew_permissions() {
    echo -e "\n${BLUE}🔧 Arreglando permisos de PHPBrew...${NC}"
    
    PHPBREW_PATH=$(which phpbrew)
    
    if [ -z "$PHPBREW_PATH" ]; then
        echo -e "${RED}❌ No se pudo encontrar la ubicación de phpbrew.${NC}"
        return 1
    fi
    
    echo -e "${YELLOW}PHPBrew se encuentra en: ${PHPBREW_PATH}${NC}"
    echo -e "${YELLOW}Se requiere privilegios sudo para arreglar los permisos.${NC}"
    
    sudo chown $(whoami) "$PHPBREW_PATH"
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Permisos actualizados correctamente.${NC}"
        # Try self-update after fixing permissions
        echo -e "\n${BLUE}🔄 Intentando actualizar PHPBrew...${NC}"
        phpbrew self-update
    else
        echo -e "${RED}❌ No se pudieron actualizar los permisos.${NC}"
    fi
}

# Function to install a specific PHP version
install_php_version() {
    local required_version="$1"
    local install_mode="${2:-interactive}" # Can be 'interactive' or 'auto'
    
    # Actualizar lista de versiones primero
    echo -e "${BLUE}🔄 Actualizando lista de versiones...${NC}"
    phpbrew update
    
    # Verificar si la versión está disponible
    echo -e "${BLUE}🔍 Consultando versiones disponibles de PHP ${required_version}...${NC}"
    local available_versions=$(phpbrew known | grep "^${required_version}: " | sed 's/^.*: //' | sed 's/,//g')
    
    if [ -z "$available_versions" ]; then
        echo -e "${RED}❌ No se encontraron versiones disponibles de PHP ${required_version}.${NC}"
        return 1
    fi
    
    # Mostrar versiones disponibles
    echo -e "${GREEN}✅ Versiones disponibles de PHP ${required_version}:${NC}"
    
    # Format the available versions for better display
    for version in $available_versions; do
        echo -e "   - ${CYAN}$version${NC}"
    done
    
    # Seleccionar la versión más reciente
    local latest_version=$(echo "$available_versions" | awk '{print $1}')
    echo -e "\n${BLUE}🔍 Seleccionando la versión más reciente: ${GREEN}$latest_version${NC}"
    
    # Create full version string (php-X.Y.Z)
    local full_version="php-$latest_version"
    
    # Determine if we should install
    local do_install=false
    
    if [ "$install_mode" = "auto" ]; then
        # Auto mode - install without asking
        do_install=true
    else
        # Interactive mode - ask for confirmation
        echo -e "${YELLOW}¿Desea instalar PHP $latest_version con las variantes por defecto? (s/n)${NC}"
        read -r install_answer
        
        if [[ $install_answer =~ ^[Ss]$ ]]; then
            do_install=true
        fi
    fi
    
    # Proceed with installation if confirmed
    if [ "$do_install" = true ]; then
        echo -e "\n${BLUE}🚀 Instalando PHP $latest_version...${NC}"
        echo -e "${YELLOW}Esto puede tomar varios minutos.${NC}"
        
        phpbrew install "$latest_version" +default +opcache
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✅ Instalación completada con éxito.${NC}"
            echo "$full_version"
            return 0
        else
            echo -e "${RED}❌ Instalación fallida.${NC}"
            echo -e "${YELLOW}Intenta ejecutar el comando manualmente:${NC}"
            echo -e "phpbrew install $latest_version +default +opcache"
            
            # Try with minimal variants if in auto mode
            if [ "$install_mode" = "auto" ]; then
                echo -e "${BLUE}Intentando con variantes mínimas...${NC}"
                phpbrew install "$latest_version" +default
                
                if [ $? -eq 0 ]; then
                    echo -e "${GREEN}✅ Instalación básica completada con éxito.${NC}"
                    echo "$full_version"
                    return 0
                fi
            fi
            
            return 1
        fi
    else
        echo -e "${YELLOW}Instalación cancelada por el usuario.${NC}"
        return 1
    fi
}

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

# Function to switch PHP version based on composer.json with enhanced functionality
load_php_version() {
    # Option flags
    local auto_install=false
    
    # Parse command line parameters if provided
    for param in "$@"; do
        case $param in
            --auto-install)
                auto_install=true
                ;;
        esac
    done
    
    # Store the current PHP version
    local current_php_version=$(php -v | head -n 1 | awk '{print $2}' | cut -d'.' -f1,2)
    
    # Display current PHP version (minimal output for regular cd operation)
    echo -e "${BLUE}📋 PHP actual: ${GREEN}$current_php_version${NC}"
    
    # Find required PHP version from composer.json
    local required_php_version=$(find_php_version)
    
    if [ -n "$required_php_version" ]; then
        echo -e "${BLUE}🔍 Versión requerida para el proyecto: ${GREEN}$required_php_version${NC}"
        
        # Find matching installed PHP version
        local matching_php=$(find_matching_php "$required_php_version")
        
        if [ -n "$matching_php" ]; then
            # Only switch if not already using the correct version
            if [ "$current_php_version" != "$required_php_version" ]; then
                echo -e "${BLUE}🔄 Cambiando a PHP ${required_php_version} para este proyecto${NC}"
                phpbrew use "$matching_php" > /dev/null
                
                # Verify the switch was successful
                local new_php_version=$(php -v | head -n 1 | awk '{print $2}' | cut -d'.' -f1,2)
                
                if [ "$new_php_version" = "$required_php_version" ]; then
                    echo -e "${GREEN}✅ Cambio exitoso a PHP $required_php_version${NC}"
                else
                    echo -e "${RED}❌ El cambio de versión falló. PHP actual: $new_php_version${NC}"
                    echo -e "${YELLOW}Esto puede deberse a que PHPBrew no está correctamente inicializado.${NC}"
                    echo -e "Asegúrate de tener esta línea en tu ~/.zshrc:"
                    echo -e "${BLUE}[[ -e ~/.phpbrew/bashrc ]] && source ~/.phpbrew/bashrc${NC}"
                fi
            else
                echo -e "${GREEN}✅ Ya estás usando la versión correcta (PHP $required_php_version)${NC}"
            fi
        else
            echo -e "${YELLOW}⚠️ El proyecto requiere PHP ${required_php_version}, pero no está instalado${NC}"
            
            # Offer to install if auto_install is true or ask the user
            if [ "$auto_install" = true ]; then
                echo -e "${BLUE}🔄 Iniciando instalación automática de PHP $required_php_version...${NC}"
                local installed_version=$(install_php_version "$required_php_version" "auto")
                
                if [ -n "$installed_version" ]; then
                    # Switch to the newly installed version
                    echo -e "${BLUE}🔄 Cambiando a la versión recién instalada: $installed_version${NC}"
                    phpbrew use "$installed_version" > /dev/null
                fi
            else
                echo -e "${YELLOW}Ejecuta 'phpbrew install ${required_php_version}' para instalarlo${NC}"
                echo -e "${YELLOW}O usa el parámetro --auto-install para instalar automáticamente.${NC}"
            fi
        fi
    elif [ -n "$(PWD=$OLDPWD find_php_version)" ]; then
        # We've moved from a directory with a PHP requirement to one without
        # Get the default PHP version
        local default_php=$(phpbrew list | grep '\*' | awk '{print $2}')
        
        if [ -n "$default_php" ] && [ "$current_php_version" != "$(echo $default_php | grep -o '[0-9]\+\.[0-9]\+' | head -1)" ]; then
            echo -e "${BLUE}🔄 Volviendo a PHP por defecto (${default_php})${NC}"
            phpbrew use "$default_php" > /dev/null
        fi
    fi
}

# Command to fix permissions manually
phpbrew_fix() {
    fix_phpbrew_permissions
}

# Command to force installation of a specific PHP version
phpbrew_install_version() {
    if [ -z "$1" ]; then
        echo -e "${RED}❌ Debes especificar una versión de PHP para instalar.${NC}"
        echo -e "${YELLOW}Uso: phpbrew_install_version 8.2${NC}"
        return 1
    fi
    
    install_php_version "$1"
}

# Register the hook to be called when changing directories
autoload -U add-zsh-hook
add-zsh-hook chpwd load_php_version

# Run once when the shell starts
load_php_version

# Make the utility functions available in the shell
export -f phpbrew_fix
export -f phpbrew_install_version

# Output a helpful message on first load
echo -e "${MAGENTA}===============================================${NC}"
echo -e "${MAGENTA}    Auto-PHPBrew cargado correctamente       ${NC}"
echo -e "${MAGENTA}===============================================${NC}"
echo -e "${YELLOW}Comandos disponibles:${NC}"
echo -e "  ${CYAN}phpbrew_fix${NC} - Arregla permisos de PHPBrew"
echo -e "  ${CYAN}phpbrew_install_version 8.x${NC} - Instala una versión específica"
echo -e "  ${CYAN}load_php_version --auto-install${NC} - Cambia de versión con instalación automática"
echo -e "${MAGENTA}===============================================${NC}"