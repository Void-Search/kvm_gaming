#!/bin/bash

LOGFILE="/var/log/passthrough/passthrough.log"

echo_log() {
    mkdir -p /var/log/passthrough/
    rm -f /var/log/passthrough/passthrough.log
    echo "$@" | tee -a "$LOGFILE"
}

enable_passthrough() {
    echo_log "Enabling passthrough..."

    # Backup original configuration files
    cp -f /etc/default/grub /etc/default/grub.bak
    if [[ -f /etc/modprobe.d/vfio.conf ]]; then
        cp -f /etc/modprobe.d/vfio.conf /etc/modprobe.d/vfio.conf.bak
    fi
    cp -f /etc/mkinitcpio.conf /etc/mkinitcpio.conf.bak

    # Turn on vfio settings in grub
    sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="quiet/GRUB_CMDLINE_LINUX_DEFAULT="quiet amd_iommu=on vfio-pci.ids=1002:73df,1002:ab28/' /etc/default/grub
    grub-mkconfig -o /boot/grub/grub.cfg

    # Create and configure vfio.conf
    echo "options vfio-pci ids=1002:73df,1002:ab28" > /etc/modprobe.d/vfio.conf

    # Add vfio-pci to MODULES in mkinitcpio.conf
    if ! grep -q "vfio-pci" /etc/mkinitcpio.conf ; then
        sed -i '/^MODULES=/ s/"$/ vfio-pci"/' /etc/mkinitcpio.conf
    fi

    # Regenerate initramfs
    mkinitcpio -P

    echo_log "Passthrough enabled"
}

disable_passthrough() {
    echo_log "Disabling passthrough..."

    # Backup original configuration files
    cp /etc/default/grub /etc/default/grub.bak
    cp /etc/modprobe.d/vfio.conf /etc/modprobe.d/vfio.conf.bak
    cp /etc/mkinitcpio.conf /etc/mkinitcpio.conf.bak

    # Turn off vfio settings in grub
    sed -i 's/ amd_iommu=on vfio-pci.ids=1002:73df,1002:ab28//' /etc/default/grub
    grub-mkconfig -o /boot/grub/grub.cfg

    # Remove vfio.conf file
    rm -f /etc/modprobe.d/vfio.conf

    # Remove vfio-pci from MODULES in mkinitcpio.conf
    if grep -q "vfio-pci" /etc/mkinitcpio.conf ; then
        sed -i 's/vfio-pci//' /etc/mkinitcpio.conf
    fi

    # Regenerate initramfs
    mkinitcpio -P

    echo_log "Passthrough disabled"
}

function show_help() {
    echo "Usage: $0 {enable|disable|help}"
    echo "enable  : Enable GPU passthrough"
    echo "disable : Disable GPU passthrough"
    echo "help    : Display help"
}

case "$1" in
    enable)
        enable_passthrough
        ;;
    disable)
        disable_passthrough
        ;;
    help|*)
        show_help
        ;;
esac
