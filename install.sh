#!/bin/bash

# cfdisk /dev/sda
# mkfs.ext4 /dev/sda1
# ...
# mount /dev/sda1 /mnt
# mount boot ...
# pacstrap -i /mnt base base-devel 
# genfstab -U /mnt > /mnt/etc/fstab
# arch-chroot /mnt /bin/bash
# vi /etc/locale.gen
# locale-gen
# echo LANG=en_US.UTF-8 > /etc/locale.conf
# ln -sf /usr/share/zoneinfo/Europe/Bratislava /etc/localtime
# hwclock --systohc --utc
# mkinitcpio -p linux
# pacman -S grub
# grub-install --recheck /dev/sda
# grub-mkconfig -o /boot/grub/grub.cfg
# echo fenrir > /etc/hostname
# vi /etc/hosts
# systemctl enable dhcpcd
# passwd
# exit
# umount -R /mnt
# reboot
# useradd -m -G wheel -s /bin/bash juraj
# pacman -Syu mc vim htop git 
