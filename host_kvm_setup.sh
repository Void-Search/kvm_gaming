#!/bin/bash
if [ "$EUID" -ne 0 ]; then
    echo "This script must be run with root privileges. Aborting."
    exit 1
fi

# Install required packages
pacman -S --noconfirm qemu libvirt virt-manager ovmf dnsmasq bridge-utils

# Enable and start libvirtd
systemctl enable --now libvirtd

# Update GRUB configuration
GRUB_CFG="/etc/default/grub"
GRUB_LINE=$(grep -n "GRUB_CMDLINE_LINUX_DEFAULT" $GRUB_CFG | cut -d : -f 1)
sed -i "${GRUB_LINE}s/\"$/ amd_iommu=on vfio-pci.ids=1002:67df,1002:aaf0\"/" $GRUB_CFG
grub-mkconfig -o /boot/grub/grub.cfg

# Create and configure vfio.conf
echo "options vfio-pci ids=1002:67df,1002:aaf0" > /etc/modprobe.d/vfio.conf

# Add vfio-pci to MODULES in mkinitcpio.conf deso
sed -i '/^MODULES=/ s/"$/ vfio-pci"/' /etc/mkinitcpio.conf

# Regenerate initramfs
mkinitcpio -P

# Configure the virtual network bridge
## wlp37s0 is the interface
nmcli connection add type bridge ifname br1 con-name br1
nmcli connection add type bridge-slave ifname wlp37s0 con-name wlp37s0 master br1

# Create and configure the tap device
nmcli connection add type tun ifname tap1_vm con-name tap1_vm mode tap owner $(id -u) group $(id -g)
nmcli connection modify tap1_vm connection.slave-type bridge connection.master br1



# Set up internet connection sharing with the wireless interface
nmcli connection modify br1 ipv4.method shared
nmcli connection modify br1 ipv4.addresses 192.168.100.1/24
nmcli connection modify br1 ipv4.gateway 192.168.100.1

# Bring up the bridge and tap devices
nmcli connection up br1
nmcli connection up tap1


# Allocate 8192 2 MiB hugepages for the VM, 0 for the moment will try transparent hugepages.
HUGEPAGES=0
# Create hugepages
#echo "vm.nr_hugepages = $HUGEPAGES" | sudo tee /etc/sysctl.d/60-hugepages.conf
#sudo sysctl -p /etc/sysctl.d/60-hugepages.conf
echo always > /sys/kernel/mm/transparent_hugepage/enabled

# Check if the memory limits are already set
if grep -q "memlock" /etc/security/limits.conf; then
    echo "Updating existing memlock limits in /etc/security/limits.conf"
    sed -i 's/.*soft memlock.*/\* soft memlock unlimited/' /etc/security/limits.conf
    sed -i 's/.*hard memlock.*/\* hard memlock unlimited/' /etc/security/limits.conf
else
    echo "Adding new memlock limits to /etc/security/limits.conf"
    echo "* soft memlock unlimited" >> /etc/security/limits.conf
    echo "* hard memlock unlimited" >> /etc/security/limits.conf
fi

echo "Changes have been made to /etc/security/limits.conf"

# Let the user know that they need to reboot
echo "Configuration is complete. Please reboot your system for the changes to take effect."
