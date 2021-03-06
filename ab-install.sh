#!/bin/bash
#
# ab-install v0.3
#
# Based on the Arch Installation Script (AIS) and Arch Ultimate Installation
# script (AUI) written by helmuthdu (helmuthdu[at]gmail[dot]com). Modified by
# Carl Duff for Evo/Lution Linux.
#
# Modified again by Mr Green to work with ArchBang Linux
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#-----------------------------------------------------------------------

##
## Set variables, colours, and prompts
##

# Menu and installation
  checklist=( 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 )
  KEYMAP_XKB="us"
  EDIT="nano"

# Architecture
  ARCHI=$(uname -m)
  UEFI=0
  LVM=0
  LUKS=0
  LUKS_DISK="sda2"
  EFI_DISK="/boot/efi"
  ROOT_DISK="/dev/sda1"
  BOOT_DISK="/dev/sda"

# COLORS
    Bold=$(tput bold)
    Underline=$(tput sgr 0 1)
    Reset=$(tput sgr0)

    Red=$(tput setaf 1)
    Green=$(tput setaf 2)
    Yellow=$(tput setaf 3)
    Blue=$(tput setaf 4)
    Purple=$(tput setaf 5)
    Cyan=$(tput setaf 6)
    White=$(tput setaf 7)

    BRed=${Bold}$(tput setaf 1)
    BGreen=${Bold}$(tput setaf 2)
    BYellow=${Bold}$(tput setaf 3)
    BBlue=${Bold}$(tput setaf 4)
    BPurple=${Bold}$(tput setaf 5)
    BCyan=${Bold}$(tput setaf 6)
    BWhite=${Bold}$(tput setaf 7)

# Prompts
    prompt1="Enter your option: "
    prompt2="Enter n° of options (ex: 1 2 3 or 1-3): "
    prompt3="You have to manual enter the following commands, then press ${BYellow}ctrl+d${Reset} or type ${BYellow}exit${Reset}:"

# Directory variables
  AUI_DIR=$(pwd)
  DESTDIR="/mnt/install"
  mkdir -p $DESTDIR
  SOURCE="$DESTDIR/source"
  mkdir -p $SOURCE
  BYPASS="$DESTDIR/bypass"
  mkdir -p $BYPASS

# Network flag
  NET_WORK=""

# Verbose mode
  [[ $1 == -v || $1 == --verbose ]] && VERBOSE_MODE=1 || VERBOSE_MODE=0

# Log file
  LOG="${AUI_DIR}/$(basename ${0})_error.log"
  [[ -f $LOG ]] && rm -f $LOG
  PKG=""
  PKG_FAIL="${AUI_DIR}/$(basename ${0})_pkg_fail_list.log"
  [[ -f $PKG_FAIL ]] && rm -f $PKG_FAIL


#
# Set common functions
#

 error_msg() {
    local MSG="${1}"
    echo -e "${MSG}"
    exit 1
 }

  check_boot_system() {
    if [[ "$(cat /sys/class/dmi/id/sys_vendor)" == 'Apple Inc.' ]] || [[ "$(cat /sys/class/dmi/id/sys_vendor)" == 'Apple Computer, Inc.' ]]; then
      modprobe -r -q efivars || true  # if MAC
    else
      modprobe -q efivarfs            # all others
    fi
    if [[ -d "/sys/firmware/efi/" ]]; then
      ## Mount efivarfs if it is not already mounted
      if [[ -z $(mount | grep /sys/firmware/efi/efivars) ]]; then
        mount -t efivarfs efivarfs /sys/firmware/efi/efivars
      fi
      UEFI=1
      echo "UEFI Mode detected"
    else
      UEFI=0
      echo "BIOS Mode detected"
    fi
  }

  read_input() {
      read -p "$prompt1" OPTION
  }

  read_input_text() {
      read -p "$1 [y/N]: " OPTION
      echo ""
    OPTION=$(echo "$OPTION" | tr '[:upper:]' '[:lower:]')
  }

 read_input_options() {
    local line
    local packages
    if [[ $AUTOMATIC_MODE -eq 1 ]]; then
      array=("$1")
    else
      read -p "$prompt2" OPTION
      array=("$OPTION")
    fi
    for line in ${array[@]/,/ }; do
      if [[ ${line/-/} != $line ]]; then
        for ((i=${line%-*}; i<=${line#*-}; i++)); do
          packages+=($i);
        done
      else
        packages+=($line)
      fi
    done
    OPTIONS=("${packages[@]}")
  }

  print_line() { 
    printf "%$(tput cols)s\n"|tr ' ' '-'
  }
  print_title() {
    clear
    print_line
    echo -e "# ${BBlue}$1${Reset}"
    print_line
    echo ""
  }

  print_info() {
    #Console width number
    T_COLS=$(tput cols)
    echo -e "${Bold}$1${Reset}\n" | fold -sw $(( $T_COLS - 18 )) | sed 's/^/\t/'
  }

   print_info_light() {
    #Console width number
    T_COLS=$(tput cols)
    echo -e "$1\n" | fold -sw $(( $T_COLS - 18 )) | sed 's/^/\t/'
  }

  print_warning() {
    T_COLS=$(tput cols)
    echo -e "${BYellow}$1${Reset}\n" | fold -sw $(( $T_COLS - 1 ))
  }

  print_danger() {
    T_COLS=$(tput cols)
    echo -e "${BRed}$1${Reset}\n" | fold -sw $(( $T_COLS - 1 ))
  }

  checkbox() {
    #display [X] or [ ]
    [[ "$1" -eq 1 ]] && echo -e "${BGreen}(${Reset}${Bold}#${BGreen})${Reset}" || echo -e "${BRed}( ${BRed})${Reset}";
  }

  contains_element() {
    #check if an element exist in a string
    for e in "${@:2}"; do [[ $e == $1 ]] && break; done;
  }

 invalid_option() {
    print_line
    echo "Invalid option. Try another one."
    pause_function
  }

  pause_function() {
    print_line
      read -e -sn 1 -p "Press enter to continue..."
  }

  mainmenu_item() { #{{{
    echo -e "$(checkbox "$1") ${Bold}$2${Reset}"
  }

 arch_chroot() {
    arch-chroot $DESTDIR /bin/bash -c "${1}"
  }

  getkeymap_xkb() {
    local keymaps_xkb=("af - Afghani" "al - Albanian" "et - Amharic" "ma - Arabic (Morocco)" "sy - Arabic (Syria)" "am - Armenian" "az - Azerbaijani" "ml - Bambara" "by - Belarusian" "be - Belgian" "bd - Bangla" "ba - Bosnian" "bg - Bulgarian" "mm - Burmese" "cn - Chinese" "hr - Croatian" "cz - Czech" "dk - Danish" "mv - Dhivehi" "nl - Dutch" "bt - Dzongkha" "cm - English (Cameroon)" "gh - English (Ghana)" "ng - English (Nigeria)" "za - English (South Africa)" "gb - English (UK)" "us - English (US)" "ee - Estonian" "fo - Faroese" "ph - Filipino" "fi - Finnish" "fr - French" "ca - French (Canada)" "cd - French (DR Congo)" "gn - French (Guinea)" "ge - Georgian" "de - German" "at - German (Austria)" "ch - German (Switzerland)" "gr - Greek" "il - Hebrew" "hu - Hungarian" "is - Icelandic" "in - Indian" "iq - Iraqi" "it - Italian" "ie - Irish" "jp - Japanese" "kz - Kazakh" "kh - Khmer (Cambodia)" "kr - Korean" "kg - Kyrgyz" "lv - Latvian" "la - Lao" "lt - Lithuanian" "mk - Macedonian" "mt - Maltese" "md - Moldavian" "mn - Mongolian" "me - Montenegrin" "np - Nepali" "no - Norwegian" "ir - Persian" "pl - Polish" "pt - Portuguese" "br - Portuguese (Brazil)" "ro - Romanian" "ru - Russian" "rs - Serbian" "si - Slovenian" "sk - Slovak" "es - Spanish" "se - Swedish" "tz - Swahili (Tanzania)" "ke - Swahili (Kenya)" "tw - Taiwanese" "tj - Tajik" "th - Thai" "bw - Tswana" "tr - Turkish" "tm - Turkmen" "ua - Ukrainian" "pk - Urdu (Pakistan)" "uz - Uzbek" "vn - Vietnamese" "sn - Wolof")
    PS3="$prompt1"
    echo "Select keymap:"
    select KEYMAP_XKB in "${keymaps_xkb[@]}"; do
      if contains_element "$KEYMAP_XKB" "${keymaps_xkb[@]}"; then
        break
      else
        invalid_option
      fi
    done
  }

  getkeymap() {
    local keymaps=(`localectl list-keymaps`)
    PS3="$prompt1"
    echo "Select keymap:"
    select KEYMAP in "${keymaps[@]}"; do
      if contains_element "$KEYMAP" "${keymaps[@]}"; then
        break
      else
        invalid_option
      fi
    done
  }

 setlocale() {
    local locale_list=(`cat /etc/locale.gen | grep UTF-8 | sed 's/\..*$//' | sed '/@/d' | awk '{print $1}' | uniq | sed 's/#//g'`);
    PS3="$prompt1"
    echo "Select locale:"
    select LOCALE in "${locale_list[@]}"; do
      if contains_element "$LOCALE" "${locale_list[@]}"; then
        LOCALE_UTF8="${LOCALE}.UTF-8"
        break
      else
        invalid_option
      fi
    done
  }


  settimezone() {
    local zone=(`timedatectl list-timezones | sed 's/\/.*$//' | uniq`);
    PS3="$prompt1"
    echo "Select zone:"
    select ZONE in "${zone[@]}"; do
      if contains_element "$ZONE" "${zone[@]}"; then
        local subzone=(`timedatectl list-timezones | grep ${ZONE} | sed 's/^.*\///'`)
        PS3="$prompt1"
        echo "Select subzone:"
        select SUBZONE in "${subzone[@]}"; do
          if contains_element "$SUBZONE" "${subzone[@]}"; then
            break
          else
            invalid_option
          fi
        done
        break
      else
        invalid_option
      fi
    done
  }

check_archbang_requirements() {
  if [[ ${EUID} -ne 0 ]]; then
    print_danger "This script must be run with root privilages (i.e. the 'sudo' command)."
    pause_function
    exit 1
  fi

 [[ "$(ping -c 1 google.com)"  ]] && NET_WORK="active"

 if [[ ! -f /usr/bin/pacstrap ]]; then
    print_danger "Please install arch-install-scripts package and try again."
    pause_function
    exit 1
 fi
}


# SELECT KEYMAP - SETXKBMAP
# Modified by Carl Duff to use the 'setxkbmap' command rather than 'loadkeys' for the installer terminal.
select_keymap_xkb(){
  print_title "INSTALLER KEYBOARD LAYOUT"
  print_info "The setxkbmap command defines the keyboard keymap to be used in this terminal. It will also be used to set the keyboard layout for your installed desktop environment(s) / window manager(s), where installed."
  pause_function
  OPTION=n
  while [[ $OPTION != y ]]; do
    getkeymap_xkb
    read_input_text "Confirm keymap: $KEYMAP_XKB"
  done
  # we set keymap for X later on in script....
  # setxkbmap ${KEYMAP_XKB:0:2}
}

#}}}
#MIRRORLIST {{{
# We could simply edit mirrorlist directly rather than had hold user
configure_mirrorlist(){

  print_title "EDIT MIRRORLISTS"
  print_info "Edit mirrorlits to the nearest to your location ie: if you live in the US you would select US mirrors"
  pause_function

  $EDIT /etc/pacman.d/mirrorlist
}
#}}}
#UMOUNT PARTITIONS {{{
umount_partitions(){
  mounted_partitions=(`lsblk | grep ${DESTDIR} | awk '{print $7}' | sort -r`)
  swapoff -a
  for i in ${mounted_partitions[@]}; do
    umount $i
  done
}
#}}}
#CREATE PARTITION SCHEME {{{
create_partition_scheme(){
  LUKS=0
  LVM=0
  select_device(){
    devices_list=(`lsblk -d | awk '{print "/dev/" $1}' | grep 'sd\|hd\|vd'`);
    PS3="$prompt1"
    echo -e "Select partition:\n"
    select device in "${devices_list[@]}"; do
      if contains_element "${device}" "${devices_list[@]}"; then
        break
      else
        invalid_option
      fi
    done
    BOOT_DISK=$device
  }
  print_title "PARTITION DISK"
  print_info "Partitioning logically divides a hard drive into seperate sections (e.g. boot, root, home, and swap)."
  print_info "Although partitioning is generally up to the user, UEFI systems MUST have a separate boot partition using filesystem FAT32."
  partition_layout=("Standard" "Plus LVM" "Plus Encryption and LVM")
  PS3="$prompt1"
  echo -e "Select partition scheme:"
  select OPT in "${partition_layout[@]}"; do
    case "$REPLY" in
      1)
        create_partition
        ;;
      2)
        create_partition
        setup_lvm
        ;;
      3)
        create_partition
        setup_luks
        setup_lvm
        ;;
      *)
        invalid_option
        ;;
    esac
    [[ -n $OPT ]] && break
  done
}
#}}}
#SETUP PARTITION{{{
# Modified by Carl Duff. Integrated Gparted, and dropped most of the other partitioning tools.
create_partition(){
  print_title "CHOOSE PARTITIONING TOOL"
  print_info "Text-based tools available are cfdisk for BIOS systems (MBR), or gdisk for UEFI systems (GPT)."
  print_warning "It is not necessary to actually format the partitions created, as this will be undertaken later."
  apps_list=("cfdisk" "gdisk");
  PS3="$prompt1"
  echo -e "Select partition program:"
  select OPT in "${apps_list[@]}"; do
    if contains_element "$OPT" "${apps_list[@]}"; then
      select_device
      case $OPT in
        *)
          $OPT ${device}
          ;;
      esac
      break
    else
      invalid_option
    fi
  done
}
#}}}
#SETUP LUKS {{{
setup_luks(){
  print_title "SET UP ENCRYPTION"
  print_info "The Linux Unified Key Setup or LUKS is a disk-encryption specification created by Clemens Fruhwirth and originally intended for Linux."
  print_danger "\tDo not use this for boot partitions"
  block_list=(`lsblk | grep 'part' | awk '{print "/dev/" substr($1,3)}'`)
  PS3="$prompt1"
  echo -e "Select partition:"
  select OPT in "${block_list[@]}"; do
    if contains_element "$OPT" "${block_list[@]}"; then
      cryptsetup luksFormat $OPT
      cryptsetup open --type luks $OPT crypt
      LUKS=1
      LUKS_DISK=`echo ${OPT} | sed 's/\/dev\///'`
      break
    elif [[ $OPT == "Cancel" ]]; then
      break
    else
      invalid_option
    fi
  done
}
#}}}
#SETUP LVM {{{
setup_lvm(){
  print_title "SET UP LOGICAL VOLUME MANAGEMENT (LVM)"
  print_info "LVM is a logical volume manager for the Linux kernel; it manages disk drives and similar mass-storage devices. "
  print_warning "Last partition will take 100% of free space left"
  if [[ $LUKS -eq 1 ]]; then
    pvcreate /dev/mapper/crypt
    vgcreate lvm /dev/mapper/crypt
  else
    block_list=(`lsblk | grep 'part' | awk '{print "/dev/" substr($1,3)}'`)
    PS3="$prompt1"
    echo -e "Select partition:"
    select OPT in "${block_list[@]}"; do
      if contains_element "$OPT" "${block_list[@]}"; then
        pvcreate $OPT
        vgcreate lvm $OPT
        break
      else
        invalid_option
      fi
    done
  fi
  read -p "Enter number of partitions [ex: 2]: " number_partitions
  i=1
  while [[ $i -le $number_partitions ]]; do
    read -p "Enter $iª partition name [ex: home]: " partition_name
    if [[ $i -eq $number_partitions ]]; then
      lvcreate -l 100%FREE lvm -n ${partition_name}
    else
      read -p "Enter $iª partition size [ex: 25G, 200M]: " partition_size
      lvcreate -L ${partition_size} lvm -n ${partition_name}
    fi
    i=$(( i + 1 ))
  done
  LVM=1
}
#}}}
#SELECT|FORMAT PARTITIONS {{{
format_partitions(){
  print_title "FORMAT PARTITION(S)"
  print_info "This step will select and format the selected partiton(s) where Arch will be installed"
  print_danger "\tAll data on the ROOT and SWAP partition will be LOST."
  i=0

  block_list=(`lsblk | grep 'part\|lvm' | awk '{print substr($1,3)}'`)

  # check if there is no partition
  if [[ ${#block_list[@]} -eq 0 ]]; then
    print_danger "No partition found! Please re-check your partitions."
    pause_function
    create_partition
  fi

  partitions_list=()
  for OPT in ${block_list[@]}; do
    check_lvm=`echo $OPT | grep lvm`
    if [[ -z $check_lvm ]]; then
      partitions_list+=("/dev/$OPT")
    else
      partitions_list+=("/dev/mapper/$OPT")
    fi
  done

  # partitions based on boot system
  if [[ $UEFI -eq 1 ]]; then
    partition_name=("root" "EFI" "swap" "another")
  else
    partition_name=("root" "swap" "another")
  fi

  select_filesystem(){
    filesystems_list=( "btrfs" "ext2" "ext3" "ext4" "f2fs" "jfs" "nilfs2" "ntfs" "vfat" "xfs");
    PS3="$prompt1"
    echo -e "Select filesystem:\n"
    select filesystem in "${filesystems_list[@]}"; do
      if contains_element "${filesystem}" "${filesystems_list[@]}"; then
        break
      else
        invalid_option
      fi
    done
  }

  disable_partition(){
    #remove the selected partition from list
    unset partitions_list[${partition_number}]
    partitions_list=(${partitions_list[@]})
    #increase i
    [[ ${partition_name[i]} != another ]] && i=$(( i + 1 ))
  }

  format_partition(){
    read_input_text "Confirm format $1 partition"
    if [[ $OPTION == y ]]; then
      [[ -z $3 ]] && select_filesystem || filesystem=$3
      mkfs.${filesystem} $1 \
        $([[ ${filesystem} == xfs || ${filesystem} == btrfs ]] && echo "-f") \
        $([[ ${filesystem} == vfat ]] && echo "-F32")
      fsck $1
      mkdir -p $2
      mount -t ${filesystem} $1 $2
      disable_partition
    fi
  }

  format_swap_partition(){
    read_input_text "Confirm format $1 partition"
    if [[ $OPTION == y ]]; then
      mkswap $1
      swapon $1
      disable_partition
    fi
  }

  create_swap(){
    swap_options=("partition" "file" "skip");
    PS3="$prompt1"
    echo -e "Select ${BYellow}${partition_name[i]}${Reset} filesystem:\n"
    select OPT in "${swap_options[@]}"; do
      case "$REPLY" in
        1)
          select partition in "${partitions_list[@]}"; do
            #get the selected number - 1
            partition_number=$(( $REPLY - 1 ))
            if contains_element "${partition}" "${partitions_list[@]}"; then
              format_swap_partition "${partition}"
            fi
            break
          done
          break
          ;;
        2)
          total_memory=`grep MemTotal /proc/meminfo | awk '{print $2/1024}' | sed 's/\..*//'`
          fallocate -l ${total_memory}M ${DESTDIR}/swapfile
          chmod 600 ${DESTDIR}/swapfile
          mkswap ${DESTDIR}/swapfile
          swapon ${DESTDIR}/swapfile
          i=$(( i + 1 ))
          break
          ;;
        3)
          i=$(( i + 1 ))
          break
          ;;
        *)
          invalid_option
          ;;
      esac
    done
  }

  check_mountpoint(){
    if mount | grep $2; then
      echo "Successfully mounted"
      disable_partition "$1"
    else
      echo "WARNING: Not Successfully mounted"
    fi
  }

  set_efi_partition(){
    efi_options=("/boot/efi" "/boot")
    PS3="$prompt1"
    echo -e "Select EFI mountpoint:\n"
    select EFI_DISK in "${efi_options[@]}"; do
      if contains_element "${EFI_DISK}" "${efi_options[@]}"; then
        break
      else
        invalid_option
      fi
    done
  }

  while true; do
    PS3="$prompt1"
    if [[ ${partition_name[i]} == swap ]]; then
      create_swap
    else
      echo -e "Select ${BYellow}${partition_name[i]}${Reset} partition:\n"
      select partition in "${partitions_list[@]}"; do
        #get the selected number - 1
        partition_number=$(( $REPLY - 1 ))
        if contains_element "${partition}" "${partitions_list[@]}"; then
          case ${partition_name[i]} in
            root)
              ROOT_PART=`echo ${partition} | sed 's/\/dev\/mapper\///' | sed 's/\/dev\///'`
              ROOT_DISK=${partition}
              format_partition "${partition}" "${DESTDIR}"
              ;;
            EFI)
              set_efi_partition
              read_input_text "Format ${partition} partition"
              if [[ $OPTION == y ]]; then
                format_partition "${partition}" "${DESTDIR}${EFI_DISK}" vfat
              else
                mkdir -p "${DESTDIR}${EFI_DISK}"
                mount -t vfat "${partition}" "${DESTDIR}${EFI_DISK}"
                check_mountpoint "${partition}" "${DESTDIR}${EFI_DISK}"
              fi
              ;;
            another)
              read -p "Mountpoint [ex: /home]:" directory
              [[ $directory == "/boot" ]] && BOOT_DISK=`echo ${partition} | sed 's/[0-9]//'`
              select_filesystem
              read_input_text "Format ${partition} partition"
              if [[ $OPTION == y ]]; then
                format_partition "${partition}" "${DESTDIR}${directory}" "${filesystem}"
              else
                read_input_text "Confirm fs="${filesystem}" part="${partition}" dir="${directory}""
                if [[ $OPTION == y ]]; then
                  mkdir -p ${DESTDIR}${directory}
                  mount -t ${filesystem} ${partition} ${DESTDIR}${directory}
                  check_mountpoint "${partition}" "${DESTDIR}${directory}"
                fi
              fi
              ;;
          esac
          break
        else
          invalid_option
        fi
      done
    fi
    #check if there is no partitions left
    if [[ ${#partitions_list[@]} -eq 0 && ${partition_name[i]} != swap ]]; then
      break
    elif [[ ${partition_name[i]} == another ]]; then
      read_input_text "Configure more partitions"
      [[ $OPTION != y ]] && break
    fi
  done
  pause_function
}


# Install ArchBang from iso image no net required
install_root_image(){
  print_title "INSTALL SYSTEM"
  echo

# mount image file
  inst_log="/tmp/installer.log"
  AIROOTIMG="/run/archiso/sfs/airootfs/airootfs.img"
  mkdir -p $BYPASS
  mount $AIROOTIMG $BYPASS
# copy files from bypass to install device
  echo "Installing please wait..."
  rsync -a --info=progress2 $BYPASS/ $DESTDIR/
  umount -l $BYPASS
# remove abinstall from openbox menu
  sed -i '/abinstall/,+3d' $DESTDIR/home/ablive/.config/obmenu-generator/schema.pl
# set xkeyboard map
  sed -i "s/us/${KEYMAP_XKB:0:2}/g" $DESTDIR/etc/X11/xorg.conf.d/01-keyboard-layout.conf
# add in password again for sudo
  sed -i '/^%wheel/s/NOPASSWD://g' $DESTDIR/etc/sudoers
# set /home/ablive with user permissions
  arch_chroot "chown ablive:users /home/ablive -R &> /dev/null"
# set up kernel for mkiniticpio
  cp /run/archiso/bootmnt/arch/boot/${ARCHI}/vmlinuz ${DESTDIR}/boot/vmlinuz-linux
# put live driver into new install
  cp /etc/X11/xorg.conf.d/20-gpudriver.conf ${DESTDIR}/etc/X11/xorg.conf.d/20-gpudriver.conf &>/dev/null
# copy over new mirrorlist
  cp /etc/pacman.d/mirrorlist ${DESTDIR}/etc/pacman.d/mirrorlist
# Clean up new install
  rm -f ${DESTDIR}/usr/bin/abinstall &> /dev/null
  rm -f ${DESTDIR}/usr/bin/lastmin &> /dev/null
  rm -rf ${DESTDIR}/vomi &> /dev/null
  rm -rf ${BYPASS} &> /dev/null
  rm -rf ${DESTDIR}/source &> /dev/null
  rm -rf ${DESTDIR}/src &> /dev/null
  rmdir ${DESTDIR}/bypass &> /dev/null
  rmdir ${DESTDIR}/src &> /dev/null
  rmdir ${DESTDIR}/source &> /dev/null

# clean out archiso files from install
  find ${DESTDIR}/usr/lib/initcpio -name archiso* -type f -exec rm '{}' \;

# systemd
  rm ${DESTDIR}/etc/systemd/system/default.target &> /dev/null
  arch_chroot  "/usr/bin/systemctl -f disable lastmin.service || true"
#  arch_chroot  "/usr/bin/systemctl -f disable multi-user.target || true"
#  arch_chroot  "/usr/bin/systemctl -f disable pacman-init.service || true"
#  rm ${DESTDIR}/etc/systemd/system/lastmin.service &> /dev/null
 
# remove pacman-init keys wil have to be set up by user
#  rm ${DESTDIR}/etc/systemd/system/pacman-init.service &> /dev/null

  sed -i 's/volatile/auto/g' /${DESTDIR}/etc/systemd/journald.conf

# Stop pacman complaining
  arch_chroot "/usr/bin/mkdir -p /var/lib/pacman/sync"
  arch_chroot "/usr/bin/touch /var/lib/pacman/sync/{core.db,extra.db,community.db}"

}

#}}}
#CONFIGURE FSTAB {{{
configure_fstab(){
  print_title "CONFIGURE FSTAB"
  print_info "The /etc/fstab (File System TABle) file determines what storage devices and partitions are to be mounted, and how they are to be used."
  echo
  if [[ ! -f ${DESTDIR}/etc/fstab.aui ]]; then
    cp ${DESTDIR}/etc/fstab ${DESTDIR}/etc/fstab.aui
  else
    cp ${DESTDIR}/etc/fstab.aui ${DESTDIR}/etc/fstab
  fi
  if [[ $UEFI -eq 1 ]]; then
    fstab_list=("DEV" "PARTUUID" "LABEL");
  else
    fstab_list=("DEV" "UUID" "LABEL");
  fi

  PS3="$prompt1"
  echo -e "Configure fstab based on:"
  select OPT in "${fstab_list[@]}"; do
    case "$REPLY" in
      1) genfstab -p ${DESTDIR} >> ${DESTDIR}/etc/fstab ;;
      2) if [[ $UEFI -eq 1 ]]; then
          genfstab -t PARTUUID -p ${DESTDIR} >> ${DESTDIR}/etc/fstab
         else
          genfstab -U -p ${DESTDIR} >> ${DESTDIR}/etc/fstab
         fi
         ;;
      3) genfstab -L -p ${DESTDIR} >> ${DESTDIR}/etc/fstab ;;
      *) invalid_option ;;
    esac
    [[ -n $OPT ]] && break
  done
  echo "Review your fstab"
  #[[ -f ${DESTDIR}/swapfile ]] && sed -i "s/\\${DESTDIR}//" ${DESTDIR}/etc/fstab
   [[ -f ${DESTDIR}/swapfile ]] && sed -i "s:\\${DESTDIR}::" ${DESTDIR}/etc/fstab 
 pause_function
  $EDIT ${DESTDIR}/etc/fstab
}
#}}}
#CONFIGURE HOSTNAME {{{
configure_hostname(){
  print_title "CONFIGURE HOSTNAME"
  print_info "A host name is a unique name created to identify a machine on a network. Host names are restricted to alphanumeric characters.\nThe hyphen (-) can be used, but a host name cannot start or end with it. Length is restricted to 63 characters."
  echo
  read -p "Hostname (e.g.: arch): " host_name
  echo "$host_name" > ${DESTDIR}/etc/hostname
  if [[ ! -f ${DESTDIR}/etc/hosts.aui ]]; then
    cp ${DESTDIR}/etc/hosts ${DESTDIR}/etc/hosts.aui
  else
    cp ${DESTDIR}/etc/hosts.aui ${DESTDIR}/etc/hosts
  fi
  arch_chroot "sed -i '/127.0.0.1/s/$/ '${host_name}'/' /etc/hosts"
  arch_chroot "sed -i '/::1/s/$/ '${host_name}'/' /etc/hosts"
}
#}}}
#CONFIGURE TIMEZONE {{{
configure_timezone(){
  print_title "CONFIGURE TIMEZONE"
  print_info "In an operating system the time (clock) is determined by four parts: Time value, Time standard, Time Zone, and DST (Daylight Saving Time if applicable)."
  OPTION=n
  while [[ $OPTION != y ]]; do
    settimezone
    read_input_text "Confirm timezone (${ZONE}/${SUBZONE})"
  done
  #arch_chroot "ln -s /usr/share/zoneinfo/${ZONE}/${SUBZONE} /etc/localtime"
  arch_chroot "ln -sf /usr/share/zoneinfo/${ZONE}/${SUBZONE} /etc/localtime"
}
#}}}
#CONFIGURE HARDWARECLOCK {{{
configure_hardwareclock(){
  print_title "CONFIGURE HARDWARE CLOCK"
  print_info "Unless you are installing alongside windows, pick UTC (Coordinated Universal Time), a global time standard."
  echo
  hwclock_list=('UTC' 'Localtime');
  PS3="$prompt1"
  select OPT in "${hwclock_list[@]}"; do
    case "$REPLY" in
      1) arch_chroot "hwclock --systohc --utc";
        ;;
      2) arch_chroot "hwclock --systohc --localtime";
        ;;
      *) invalid_option ;;
    esac
    [[ -n $OPT ]] && break
  done
}
#}}}

# CONFIGURE KEYMAP - INSTALLED SYSTEM
# Modified by Carl DUff from the select_keymap function to configure the installed system.
configure_keymap(){
  print_title "CONFIGURE KEYMAP"
  print_info "The /etc/vconsole.conf file determines the keyboard layout in the installed system's virtual console. It is not used for desktop environments."
  echo
  pause_function
  OPTION=n
  while [[ $OPTION != y ]]; do
    getkeymap
    read_input_text "Confirm keymap: $KEYMAP"
  done
  echo "KEYMAP=$KEYMAP" > ${DESTDIR}/etc/vconsole.conf
}

#CONFIGURE LOCALE - INSTALLED SYSTEM
configure_locale(){
  print_title "CONFIGURE LOCALE"
  print_info "Locales define the system language used. They are codes starting with two lower-case letters followed by two upper-case letters."
  print_info "The lower-case letters determine the language, and the upper-case letters determine the country. For example 'en_GB' means english, GREAT BRITAIN."
  pause_function
# comment out us locale
  sed -i "s/en_US.UTF-8/#en_US.UTF-8/g" ${DESTDIR}/etc/locale.gen
  OPTION=n
  while [[ $OPTION != y ]]; do
    setlocale
    read_input_text "Confirm locale ($LOCALE)"
  done
  echo 'LANG="'$LOCALE_UTF8'"' > ${DESTDIR}/etc/locale.conf
  arch_chroot "sed -i '/'${LOCALE_UTF8}'/s/^#//' /etc/locale.gen"
  arch_chroot "locale-gen"
}

#CONFIGURE MKINITCPIO - INSTALLED SYSTEM
# Amended by Carl Duff.
configure_mkinitcpio(){
  print_title "CONFIGURE MKINITCPIO"
  print_info "mkinitcpio is a Bash script used to create an initial ramdisk environment to load kernel modules."
  [[ $LUKS -eq 1 ]] && sed -i '/^HOOK/s/block/block keymap encrypt/' ${DESTDIR}/etc/mkinitcpio.conf
  [[ $LVM -eq 1 ]] && sed -i '/^HOOK/s/filesystems/lvm2 filesystems/' ${DESTDIR}/etc/mkinitcpio.conf

  arch_chroot "mkinitcpio -p linux"
}

#CONFIGURE BOOTLOADER - INSTALLED SYSTEM
# Modified by Carl Duff. Removed the "manual" options and the '--debug' flag for non-UEFI grub installations.
configure_bootloader(){
  print_title "SELECT BOOTLOADER"
  print_info "The boot loader is responsible for loading the kernel and initial RAM disk before initiating the boot process."
  print_info "Grub2 is the de-facto choice for Linux users, and is therefore recommended for beginners."
  print_warning "\tROOT Partition: ${ROOT_DISK}"
  print_warning "\tWARNING: There is no support for GRUB + LUKS/LVM."
  if [[ $UEFI -eq 1 ]]; then
    print_warning "\tUEFI Mode Detected"
    bootloaders_list=("Grub2" "Syslinux" "Gummiboot" "Skip")
  else
    print_warning "\tBIOS Mode Detected"
    bootloaders_list=("Grub2" "Syslinux" "Skip")
  fi
  PS3="$prompt1"
  echo -e "Install bootloader:\n"
  select bootloader in "${bootloaders_list[@]}"; do
    case "$REPLY" in
      1)
        bootloader="Grub2"
        break
        ;;
      2)
        bootloader="Syslinux"
        break
        ;;
      3)
        [[ $UEFI -eq 1 ]] && bootloader="Gummiboot"
        break
        ;;
      4)
        [[ $UEFI -eq 1 ]] && break || bootloader="Skip"
        ;;
      *)
        invalid_option
        ;;
    esac
  done

  case $bootloader in
    Grub2)
      print_title "INSTALL GRUB2"
      print_info "The GRand Unified Bootloader (GRUB) is responsible for starting the installed system."
      echo
      if [[ $UEFI -eq 1 ]]; then
         arch_chroot "grub-install --target=x86_64-efi --efi-directory=${EFI_DISK} --bootloader-id=arch_grub --recheck"
      else
         arch_chroot "grub-install --target=i386-pc --recheck ${BOOT_DISK}"
      fi

      arch_chroot "grub-mkconfig -o /boot/grub/grub.cfg"
      ;;

    Syslinux)
      print_title "INSTALL SYSLINUX"
      print_info "Syslinux is a collection of boot loaders capable of booting from hard drives, CDs, and over the network via PXE. It supports the fat, ext2, ext3, ext4, and btrfs file systems."
      syslinux_install_mode=("[MBR] Automatic" "[PARTITION] Automatic")
      PS3="$prompt1"
      echo -e "Syslinux Install:\n"
      select OPT in "${syslinux_install_mode[@]}"; do
        case "$REPLY" in
          1)
            arch_chroot "syslinux-install_update -iam"
            if [[ $LUKS -eq 1 ]]; then
              sed -i "s/APPEND root=.*/APPEND root=\/dev\/mapper\/${ROOT_PART} cryptdevice=\/dev\/${LUKS_DISK}:crypt ro/g" ${DESTDIR}/boot/syslinux/syslinux.cfg
            elif [[ $LVM -eq 1 ]]; then
              sed -i "s/sda[0-9]/\/dev\/mapper\/${ROOT_PART}/g" ${DESTDIR}/boot/syslinux/syslinux.cfg
            else
              sed -i "s/sda[0-9]/${ROOT_PART}/g" ${DESTDIR}/boot/syslinux/syslinux.cfg
            fi

            print_warning "The partition in question needs to be whatever you have as / (root), not /boot."
            pause_function
            $EDIT ${DESTDIR}/boot/syslinux/syslinux.cfg
            break
            ;;
          2)
            arch_chroot "syslinux-install_update -i"
            if [[ $LUKS -eq 1 ]]; then
              sed -i "s/APPEND root=.*/APPEND root=\/dev\/mapper\/${ROOT_PART} cryptdevice=\/dev\/${LUKS_DISK}:crypt ro/g" ${DESTDIR}/boot/syslinux/syslinux.cfg
            elif [[ $LVM -eq 1 ]]; then
              sed -i "s/sda[0-9]/\/dev\/mapper\/${ROOT_PART}/g" ${DESTDIR}/boot/syslinux/syslinux.cfg
            else
              sed -i "s/sda[0-9]/${ROOT_PART}/g" ${DESTDIR}/boot/syslinux/syslinux.cfg
            fi
            print_warning "The partition in question needs to be whatever you have as / (root), not /boot."
            pause_function
            $EDIT ${DESTDIR}/boot/syslinux/syslinux.cfg
            break
            ;;
          *) 
             invalid_option
            ;;
        esac
      done
      ;;
    Gummiboot)
      print_title "INSTALL GUMMIBOOT"
      print_info "Gummiboot is a UEFI boot manager written by Kay Sievers and Harald Hoyer. It is simple to configure, but can only start EFI executables, the Linux kernel EFISTUB, UEFI Shell, grub.efi, and such."
      print_warning "\tGummiboot heavily suggests that /boot is mounted to the EFI partition, not /boot/efi, in order to simplify updating and configuration."

      arch_chroot "gummiboot install"
      print_warning "Please check your .conf file"
      partuuid=`blkid -s PARTUUID ${ROOT_DISK} | awk '{print $2}' | sed 's/"//g' | sed 's/^.*=//'`
      if [[ $LUKS -eq 1 ]]; then
            echo -e "title\tArch Linux\nlinux\t/vmlinuz-linux\ninitrd\t/initramfs-linux.img\noptions\tcryptdevice=\/dev\/${LUKS_DISK}:luks root=\/dev\/mapper\/${ROOT_PART} rw" > ${DESTDIR}/boot/loader/entries/arch.conf
      elif [[ $LVM -eq 1 ]]; then
            echo -e "title\tArch Linux\nlinux\t/vmlinuz-linux\ninitrd\t/initramfs-linux.img\noptions\troot=\/dev\/mapper\/${ROOT_PART} rw" > ${DESTDIR}/boot/loader/entries/arch.conf
      else
            echo -e "title\tArch Linux\nlinux\t/vmlinuz-linux\ninitrd\t/initramfs-linux.img\noptions\troot=PARTUUID=${partuuid} rw" > ${DESTDIR}/boot/loader/entries/arch.conf
      fi

      echo -e "default  arch\ntimeout  5" > ${DESTDIR}/boot/loader/loader.conf
      pause_function
      $EDIT ${DESTDIR}/boot/loader/entries/arch.conf
      $EDIT ${DESTDIR}/boot/loader/loader.conf
      ;;
  esac
}

#ROOT PASSWORD {{{
root_password(){
  print_title "ROOT PASSWORD"
  print_info "Root is essentially the admin or super-user account."
  echo
  print_warning "Enter your new root password"
  arch_chroot "passwd"
  pause_function
}

#CREATE NEW USER
# changed to suit live image install
  create_new_user(){
  print_title "CREATE NEW USER"
  echo
  cp ${DESDIR}/usr/bin/mvuser ${DESTDIR}/root/mvuser
  arch_chroot "/root/mvuser"
  rm ${DESTDIR}/root/mvuser
  rm ${DESTDIR}/usr/bin/mvuser
  pause_function
  }


#FINISH {{{
# Modified and simplified by Carl Duff. Removed code to copy AUI script to the installed system, 
# and now automatically unmount partitions. and ask user to reboot their system manually.
finish(){
  print_title "ARCHBANG INSTALLATION COMPLETED!"

  umount_partitions

  print_info "You can reboot or power off your system."

  pause_function
  exit 0
}
#}}}

# Modified by Carl Duff. Removed original check_connection option as new one implemented.
print_title "ArchBang Installer v0.3"
check_boot_system
echo
print_info "Checking installer has been run as root, and if there is an active internet connection. Please wait..."
check_archbang_requirements
print_info "${Green}All checks passed"
echo
print_warning "Please maximise this window for best results..."
echo
echo "This script is based on the AIS and AUI scripts written by Helmuth Saatkamp."
echo
pause_function
mainmenu() {
while true
do
  print_title "AB-INSTALL v0.3: MAIN MENU"
  print_warning "Please select each menu item in order..."
  echo "${BCyan}Base Installation${Reset}"
  echo " 1) $(mainmenu_item "${checklist[1]}" "Keyboard layout")"
  echo " 2) $(mainmenu_item "${checklist[2]}" "Mirrorlist (optional)")"
  echo " 3) $(mainmenu_item "${checklist[3]}" "Partition Disk")"
  echo " 4) $(mainmenu_item "${checklist[4]}" "Install ArchBang")"
  echo " 5) $(mainmenu_item "${checklist[5]}" "Fstab")"
  echo " 6) $(mainmenu_item "${checklist[6]}" "Hostname")"
  echo " 7) $(mainmenu_item "${checklist[7]}" "Set Clock and Time Zone")"
  echo " 8) $(mainmenu_item "${checklist[8]}" "Virtual Console Keyboard Layout and System Locale")"
  echo " 9) $(mainmenu_item "${checklist[9]}" "Run Mkinitcpio")"
  echo "10) $(mainmenu_item "${checklist[10]}" "Install Bootloader")"
  echo "11) $(mainmenu_item "${checklist[11]}" "Root Password")"
  echo "12) $(mainmenu_item "${checklist[12]}" "User Account(s)")"
  echo " d) Done"
  echo ""
  read_input_options
  for OPT in ${OPTIONS[@]}; do
    case "$OPT" in
      1)
        select_keymap_xkb
        checklist[1]=1
        ;;
      2)
        configure_mirrorlist
        checklist[2]=1
        ;;
      3)
        umount_partitions
        create_partition_scheme
        format_partitions
        checklist[3]=1
        ;;
      4)
        install_root_image
        checklist[4]=1
        ;;
      5)
        configure_fstab
        checklist[5]=1
        ;;
      6)
        configure_hostname
        checklist[6]=1
        ;;
      7)
        configure_timezone
        configure_hardwareclock
        checklist[7]=1
        ;;
      8)
        configure_keymap
        configure_locale
        checklist[8]=1
        ;;
      9)
        configure_mkinitcpio
        checklist[9]=1
        ;;
      10)
        configure_bootloader
        checklist[10]=1
        ;;
      11)
        root_password
        checklist[11]=1
        ;;
      12)
        create_new_user
        checklist[12]=1
        ;;
      "d")
        finish
        ;;
      *)
        mainmenu
        ;;
    esac
  done
done
}
mainmenu
#}}}

