#!/bin/bash

# Function to check if a package is installed
check_and_install() {
    dpkg -l | grep -qw $1 || {
        echo "$1 is not installed. Installing..."
        sudo apt-get install -y $1
    }
}

# Install necessary packages if not already installed
echo "Checking for required packages..."
check_and_install realmd
check_and_install sssd-ad
check_and_install sssd-tools
check_and_install adcli
check_and_install krb5-user

# Display the current hostname and ask if the user wants to change it
current_hostname=$(hostname)
echo "Current hostname is $current_hostname."
read -p "Do you want to change the hostname? (yes/no): " change_hostname

if [ "$change_hostname" == "yes" ]; then
    read -p "Enter the new hostname: " new_hostname
    sudo hostnamectl set-hostname $new_hostname
    echo "Hostname changed to $new_hostname. A reboot is required for the changes to take effect."
    read -p "Do you want to reboot now? (yes/no): " reboot_confirm
    if [ "$reboot_confirm" == "yes" ]; then
        sudo reboot
    else
        echo "Please reboot the system manually to apply the hostname changes."
        exit 0
    fi
fi

# Prompt for necessary information
read -p "Enter your domain (e.g., yourdomain.edu): " domain
read -p "Enter your computer name (e.g., Debian3jkl34): " computer_name
read -p "Enter the AD server hostname (e.g., server.domain.edu): " ad_server
read -p "Enter your AD username for kinit: " username

# Confirm inputs
echo "You entered the following information:"
echo "Domain: $domain"
echo "Computer Name: $computer_name"
echo "AD Server: $ad_server"
echo "Username: $username"
read -p "Is everything correct? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Please rerun the script and enter the correct information."
    exit 1
fi

# Run the commands with the provided inputs
kinit $username
klist
msktutil -N -c -b 'CN=COMPUTERS' -s $computer_name/$domain -k my-keytab.keytab --computer-name $computer_name --upn ${computer_name}$ --server $ad_server --user-creds-only
msktutil -N -c -b 'CN=COMPUTERS' -s $computer_name/$computer_name -k my-keytab.keytab --computer-name $computer_name --upn ${computer_name}$ --server $ad_server --user-creds-only
kdestroy

echo "Process completed."
