#!/bin/bash
##
#     Project: ALMSI (Arch Linux Multiple Steps Install)
# Description: This bash script installs Arch Linux in a remote system
#      Author: Fabio Castelli (Muflone) <muflone@muflone.com>
#   Copyright: 2020 Fabio Castelli
#     License: GPL-3+
#
#  This program is free software: you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation, either version 3 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program.  If not, see <https://www.gnu.org/licenses/>.
##
# WARNING !!!
#     THIS SCRIPT WILL WIPE EVERY DATA IN THE REMOTE SYSTEM,
#     REINSTALLING ARCH LINUX UPON YOUR CURRENTLY INSTALLED OS.
#
# The execution process is made of multiple steps:
#     1) setup the local SSH connection to the remote system
#     2) install and setup the remote system
##

# Set input arguments
_IP_ADDRESS="${1}"
_HOSTNAME="${2}"
_STEP="${3}"

# Customized data
_SSH_KEY_DATA="AAAAB3NzaC1yc2EAAAADAQABAAABAQDI6qxAMWbP9lQMlv9V0jTocalOQvtKKptOB5ObfV4lmBZzm4ra9fqawdSvpGlJzpe/KqPbUBadarmoCFJB+jphTMXTat3iEC2+B0KbhFs0z8dLTlAd8p3yLMbLh8jDlbUkdWzGWWCgCYOvIvnbSX7zLIN4scEZCcyZTuT4PNUAd3ixogFECGu8+jJRKXaa2DpQQXL1NpaCdTC/nwxCwYBLhk8T01fLSaUIkEKoVMJtTFkoFsrX1dNIn9TkjWvqdSBKsHS5ZEdhLYkIjwOyp0cTEGdOdyeUWFyHIlxJTx2+g1ZiDjH+4zGEfhRqGUiscmxfNuTj9PVo9RWzu51ctFbv"

do_instructions()
{
    # Show instructions
    echo "Install Arch Linux in the remote system"
    echo "usage: $0 <ip address> <hostname> [step]"
    echo "step arguments could be 0-5 like the following:"
    echo "  0  Show this help"
    echo "  1  Connect to the remote system and go to the next step"
    echo "  2  Install the remote system (wipes everything)"
}

do_usage()
{
    # Show command usage
    echo "not enough arguments:"
    echo
    do_instructions
}

do_clear_ssh_host()
{
    # Clear ssh host (client side)
    sed -i "/${_IP_ADDRESS}/d" ~/.ssh/known_hosts
    _REVERSE_HOSTNAME="$(getent hosts ${_IP_ADDRESS})" || true
    if [ -n "${_REVERSE_HOSTNAME}" ]
    then
      sed -i "/${_REVERSE_HOSTNAME} | cut -d' ' -f 1)/d" ~/.ssh/known_hosts
    fi
}

do_store_ssh_key()
{
    # Save SSH public key for future easier access
    ssh -o PubkeyAuthentication=no -o StrictHostKeyChecking=no "root@${_IP_ADDRESS}" "
        mkdir -p ~/.ssh
        chmod u=rwx,go= ~/.ssh
        echo \"ssh-rsa ${_SSH_KEY_DATA}\" >> ~/.ssh/authorized_keys
        chmod u=rw,go= ~/.ssh/authorized_keys
        # Restore SELinux permissions on .ssh
        if type restorecon >/dev/null 2>&1; then
            restorecon -F ~/.ssh ~/.ssh/authorized_keys;
        fi
    "
}

do_remote_command()
{
    # Connect to the remote system using root user
    set +o pipefail
    ssh -o PubkeyAuthentication=yes "root@${_IP_ADDRESS}" $@
    set -o pipefail
}

do_get_network()
{
    # Get the first interface name and public network address
    _INTERFACE="$(find /sys/class/net ! -type d | xargs --max-args=1 realpath | awk -F\/ '/pci/{print $NF}' | head -n 1)"
    #_IP_ADDRESS="$(curl ipecho.net/plain)"
    _GATEWAY="$(ip route | grep '^default' | cut -d' ' -f 3)"
}

do_install_arch_linux()
{
    # Install Arch Linux using vps2arch
    if command -v wget
    then
        wget http://tinyurl.com/vps2arch
    else
        curl -L -o vps2arch http://tinyurl.com/vps2arch
    fi
    # The command may fail while completing the installation
    sh ./vps2arch || true
}

do_set_network()
{
    # systemd-networkd configuration
    cat << EOF > /etc/systemd/network/20-wired.network
[Match]
Name=${_INTERFACE}

[Network]
Address=${_IP_ADDRESS}/24
Gateway=${_GATEWAY}
DNS=8.8.8.8
EOF
    ln -sf /usr/lib/systemd/system/systemd-networkd.service /etc/systemd/system/dbus-org.freedesktop.network1.service
    ln -sf /usr/lib/systemd/system/systemd-networkd.service /etc/systemd/system/multi-user.target.wants/
    mkdir -p /etc/systemd/system/sockets.target.wants
    ln -sf /usr/lib/systemd/system/systemd-networkd.socket /etc/systemd/system/sockets.target.wants/
    mkdir -p /etc/systemd/system/network-online.target.wants
    ln -sf /usr/lib/systemd/system/systemd-networkd-wait-online.service /etc/systemd/system/network-online.target.wants/
    ln -sf /usr/lib/systemd/system/systemd-resolved.service /etc/systemd/system/dbus-org.freedesktop.resolve1.service
    ln -sf /usr/lib/systemd/system/systemd-resolved.service /etc/systemd/system/multi-user.target.wants/
}

do_system_setup()
{
    # SSHd activation
    echo "PermitRootLogin yes" >> /etc/ssh/sshd_config
    ln -sf /usr/lib/systemd/system/sshd.service /etc/systemd/system/multi-user.target.wants/

    # System configuration
    echo "alias htop='TERM=xterm-color htop'" >> ~/.bash_aliases
    echo "alias ll='ls -l --color=always'" >> ~/.bash_aliases
    echo "alias lh='ls -l --color=always --human-readable'" >> ~/.bash_aliases
    echo "alias ..='cd ..'" >> ~/.bash_aliases
    echo "[ -f ~/.bash_aliases ] && . ~/.bash_aliases" > ~/.bash_profile

    # Save ssh key
    mkdir -p ~/.ssh
    chmod u=rwx,go= ~/.ssh
    echo "ssh-rsa ${_SSH_KEY_DATA}" >> ~/.ssh/authorized_keys
    chmod u=rw,go= ~/.ssh/authorized_keys
    # Restore SELinux permissions on .ssh
    if type restorecon >/dev/null 2>&1; then
        restorecon -F ~/.ssh ~/.ssh/authorized_keys;
    fi

    # Set hostname
    echo "${_HOSTNAME}" > /etc/hostname

    # Install updates
    cp /etc/pacman.d/mirrorlist{,.bak}
    #echo 'Server = https://mirrors.xtom.com/archlinux/$repo/os/$arch' >> /etc/pacman.d/mirrorlist
    #echo 'Server = https://mirror.stephen304.com/archlinux/$repo/os/$arch' >> /etc/pacman.d/mirrorlist
    reflector --verbose --latest 5 --sort rate --save /etc/pacman.d/mirrorlist
    pacman -Syu --noconfirm nano htop iotop net-tools linux-lts

    # Set timezone and locale configuration
    ln -s /usr/share/zoneinfo/Europe/Rome /etc/localtime
    echo 'en_US.UTF-8 UTF-8' >> /etc/locale.gen
    echo 'it_IT.UTF-8 UTF-8' >> /etc/locale.gen
    locale-gen
}

do_cleanup()
{
    # Pacman cache cleanup (cannot use paccache/pacman for random lock-ups)
    find /var/cache/pacman/pkg -type f -name '*.zst' -delete
}

#
# Program start
#
set -e
set -u
set -o pipefail

# Check arguments count
if [ $# -lt 3 ]
then
  # Show usage
  do_usage
  exit 2
fi

# Set step value with default value
_STEP="${_STEP:=0}"

case ${_STEP} in
  0)
    do_instructions
    exit 1
    ;;
  1)
    # Enable SSH access using SSH key
    do_clear_ssh_host
    do_store_ssh_key
    # Upload a copy of this script
    scp "$0" "root@${_IP_ADDRESS}":/root
    # Execute the next step in the remote system
    do_remote_command "bash \"/root/$(basename "$0")\" \"${_IP_ADDRESS}\" \"${_HOSTNAME}\" 2"
    # Clear local SSH key
    do_clear_ssh_host
    # Operation successfull
    echo "installation completed, please wait until the system reboots"
    sleep 5
    echo "press CTRL+C to stop the ping activity"
    ping "${_IP_ADDRESS}"
    ;;
  2)
    # Save network settings
    do_get_network
    echo "${_INTERFACE} ${_IP_ADDRESS} ${_GATEWAY}"
    # Install Arch Linux
    do_install_arch_linux
    # Restore network setup
    do_set_network
    # Perform system setup
    do_system_setup
    # Perform cleanup
    do_cleanup
    # Save all data, reboot and disconnect from the remote site
    echo "saving all data and rebooting the system..."
    sync
    nohup reboot -f &> /dev/null < /dev/null &
    exit 0
    ;;
  *)
    # This step is not used
    do_usage
    exit 3
    ;;
esac

exit 4
