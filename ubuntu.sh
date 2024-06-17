#!/bin/bash

# Define color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# check if a package is installed and list missing
check_packages() {
    missing_packages=()
    for package in "$@"; do
        if ! dpkg -l | grep -qw "$package"; then
            missing_packages+=("$package")
        fi
    done
}

# Check for required packages
required_packages=(realmd sssd-ad sssd-tools adcli krb5-user)
check_packages "${required_packages[@]}"

if [ ${#missing_packages[@]} -ne 0 ]; then
    echo -e "${RED}The following packages are missing and need to be installed: \n\t${missing_packages[*]}${NC}"
    read -p "Install these packages? (yes/no): " install_confirm

    if [ "$install_confirm" != "yes" ]; then
        echo -e "${RED}Installation aborted.${NC}"
        exit 1
    fi

    # Install missing packages
    sudo apt update
    for package in "${missing_packages[@]}"; do
        sudo apt install -y "$package"
    done
else
    echo -e "${GREEN}All required packages are already installed.${NC}"
fi

# Display the current hostname and ask if the user wants to change it
current_hostname=$(hostname)
echo -e "${YELLOW}Current hostname is $current_hostname.${NC}"
read -p "Do you want to change the hostname? (yes/no): " change_hostname

if [ "$change_hostname" == "yes" ]; then
    read -p "Enter the new hostname: " new_hostname
    sudo hostnamectl set-hostname $new_hostname
    echo -e "${GREEN}Hostname changed to $new_hostname. A reboot is required for the changes to take effect.${NC}"
    read -p "Do you want to reboot now? (yes/no): " reboot_confirm
    if [ "$reboot_confirm" == "yes" ]; then
        sudo reboot
    else
        echo -e "${YELLOW}Please reboot the system manually to apply the hostname changes.${NC}"
        exit 0
    fi
fi

# Prompt for necessary information
read -p "Enter your domain (e.g., yourdomain.edu): " domain
read -p "Enter your computer name (e.g., Debian3jkl34): " computer_name
read -p "Enter the AD server hostname (e.g., server.domain.edu): " ad_server
read -p "Enter your AD username for kinit: " username

# Confirm inputs
echo -e "${YELLOW}You entered the following information:${NC}"
echo "Domain: $domain"
echo "Computer Name: $computer_name"
echo "AD Server: $ad_server"
echo "Username: $username"
read -p "Is everything correct? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo -e "${RED}Please rerun the script and enter the correct information.${NC}"
    exit 1
fi

# Create /etc/sssd/sssd.conf file
sssd_conf="[sssd]
domains = $domain
config_file_version = 2
services = nss, pam
[domain/$domain]
default_shell = /bin/bash
krb5_store_password_if_offline = True
cache_credentials = True
krb5_realm = ${domain^^}
realmd_tags = manages-system joined-with-adcli
id_provider = ad
fallback_homedir = /home/%u@%d
ad_domain = $domain
use_fully_qualified_names = True
ldap_id_mapping = True
access_provider = ad"

echo -e "${YELLOW}The following configuration will be written to /etc/sssd/sssd.conf:${NC}"
echo "$sssd_conf"
read -p "Do you want to proceed with creating this file? (yes/no): " create_conf

if [ "$create_conf" == "yes" ]; then
    echo "$sssd_conf" | sudo tee /etc/sssd/sssd.conf > /dev/null
    sudo chmod 600 /etc/sssd/sssd.conf
    echo -e "${GREEN}/etc/sssd/sssd.conf created successfully.${NC}"
else
    echo -e "${RED}Configuration file creation aborted.${NC}"
    exit 1
fi

# Run the commands with the provided inputs
kinit $username
klist
msktutil -N -c -b 'CN=COMPUTERS' -s $computer_name/$domain -k my-keytab.keytab --computer-name $computer_name --upn ${computer_name}$ --server $ad_server --user-creds-only
msktutil -N -c -b 'CN=COMPUTERS' -s $computer_name/$computer_name -k my-keytab.keytab --computer-name $computer_name --upn ${computer_name}$ --server $ad_server --user-creds-only
kdestroy

echo -e "${GREEN}Process completed.${NC}"
