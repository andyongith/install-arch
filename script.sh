#!/usr/bin/bash

pkg_i_use=(man-db git nerd-fonts noto-fonts noto-fonts-emoji noto-fonts-cjk noto-fonts-extra firefox kitty tmux ranger python-pillow tldr htop neofetch github-cli bitwarden telegram-desktop discord virtualbox vlc wget tar unrar bash-completion)

### Taking User Inputs
#
function choose_from_menu()
{
  local prompt=$1 outvar=$2
  shift; shift
  local options=("$@") count=${#@} selected=0
  local esc=$(echo -en "\e")
  
  echo $prompt
  while true
  do
    local index=0
    for opt in "${options[@]}"
    do
      if [[ $selected == $index ]]
      then
        echo -e " >$((index+1)) \e[7m$opt\e[0m"
      else
        echo "  $((index+1)) $opt"
      fi
      ((index+=1))
    done
    ##
    local key0
    local key
    read -s -n1 key0
    if [[ $key0 == "" ]]
    then
      break
    elif [[ $key0 == $esc ]]
    then
      read -s -n2 key
      if [[ $key == [A ]]
      then
        ((selected-=1))
        [[ $selected -lt 0 ]] && ((selected = $count - 1))
      elif [[ $key == [B ]]
      then
        ((selected+=1))
        [[ $selected -ge $count ]] && selected=0
      fi
    fi
    echo -en "\e[${count}A"
  done

  printf -v $outvar "${options[$selected]}"
  REPLY=$(($selected+1))
}

function show_all_vars() {
  echo " ESP           : $ESP"
  echo " ROOT          : $ROOT"
  echo " USER_NAME     : $USER_NAME"
  echo " PASSWORD      : $PASSWORD"
  echo " RTPASSWD      : $RTPASSWD"
  echo " HOST_NAME     : $HOST_NAME"
  echo " display_mgr   : $display_mgr"
  echo " setup_pkg     : ${setup_pkg[@]}"
  echo " extra_pkg     : ${extra_pkg[@]}"
  echo " BOOTLOADER_ID : $BOOTLOADER_ID"
}

function show_page {
  clear
  show_all_vars
  echo -------------------------------------------------------
  echo
}

function select_partitions() {
  ESP=
  ROOT=
  show_page
  all_partitions=($(blkid | cut -d: -f1 | sort))
  choose_from_menu "Choose EFI partiton:" ESP ${all_partitions[@]}
  show_page
  choose_from_menu "Choose ROOT partiton:" ROOT ${all_partitions[@]/$ESP}
}
select_partitions

function select_user_and_hostname() {
  USER_NAME=
  PASSWORD=
  RTPASSWD=
  HOST_NAME=
  show_page
  echo -n "Enter username: "
  while [[ $USER_NAME == "" ]]; do read USER_NAME; done
  echo -n "Enter password: "
  while [[ $PASSWORD == "" ]]; do read PASSWORD; done
  echo
  choose_from_menu "Do you want to have the same password as root" SAME_PASSWORD "yes" "no"
  if [[ $SAME_PASSWORD == "yes" ]]
  then
    RTPASSWD=$PASSWORD
  else
    echo -n "Enter root password: "
    while [[ $RTPASSWD == "" ]]; do read RTPASSWD; done
  fi

  show_page
  echo -n "Enter hostname: "
  while [[ $HOST_NAME == "" ]]; do read HOST_NAME; done
}
select_user_and_hostname

function select_gui_setup() {
  display_mgr=
  setup_pkg=()
  extra_pkg=
  show_page
  choose_from_menu "Choose your GUI setup" setup_pkg "xorg gnome gnome-extra gdm" "xorg plasma-meta kde-applications-meta sddm" "Minimal"
  case $REPLY in
    1) display_mgr=gdm ;;
    2) display_mgr=sddm ;;
    *) setup_pkg=() ;;
  esac
  setup_pkg=($setup_pkg)
  echo
  echo "Some additional packages that I use:" 
  echo ${pkg_i_use[@]}
  echo
  choose_from_menu "Do you want these packages too?" install_my_pkg "yes" "no"
  echo
  echo "Extra packages to install(separated by white space): "
  read extra_pkg
  [[ $install_my_pkg == "yes" ]] && extra_pkg=(${extra_pkg[@]} ${pkg_i_use[@]})
}
select_gui_setup

BOOTLOADER_ID="Arch"
function select_bootloader_id() {
  show_page
  BOOTLOADER_ID=
  echo -n "Enter bootloader-id: "
  while [[ $BOOTLOADER_ID == "" ]]; do read BOOTLOADER_ID; done
}

while true
do
  show_page
  choose_from_menu "Do you need any changes?" change_to_make "Partitions" "User and hostname" "GUI setup" "bootloader-id" "Abort" "No, continue"
  case $REPLY in
    1) select_partitions ;;
    2) select_user_and_hostname ;;
    3) select_gui_setup ;;
    4) select_bootloader_id ;;
    5) exit 1 ;;
    *) break ;;
  esac
done

show_page

### Installation
#
mkfs.vfat -F32 -n "Arch-ESP" $ESP
mkfs.ext4 -L "Arch-root" $ROOT

mount $ROOT /mnt/
mkdir -p /mnt/boot/efi
mount $ESP /mnt/boot/efi/

customize-pacman-conf() {
  if grep -q "#Color" $1; then
    sed -i "`grep -n "#Color" $1 | cut -d: -f1`s/.*/Color/" $1
  fi
  if grep -q "#VerbosePkgLists" $1; then
    sed -i "`grep -n "#VerbosePkgLists" $1 | cut -d: -f1`s/.*/VerbosePkgLists/" $1
  fi
  if grep -q "#ParallelDownloads" $1; then
    sed -i "`grep -n "#ParallelDownloads" $1 | cut -d: -f1`s/.*/ParallelDownloads = 5\nILoveCandy/" $1
  fi
}
customize-pacman-conf /etc/pacman.conf

echo
echo "Updating mirrorlist... This might take some time"
reflector -c IN --sort rate --save /etc/pacman.d/mirrorlist
pacman -Sy --noconfirm archlinux-keyring
pacstrap /mnt/ \
  base base-devel \
  linux-lts linux-firmware linux-lts-headers \
  efibootmgr grub os-prober \
  intel-ucode amd-ucode \
  exfat-utils ntfs-3g \
  networkmanager \
  vi vim \
  reflector \
  ${setup_pkg[@]} ${extra_pkg[@]} \
  --noconfirm --needed
cp /etc/pacman.d/mirrorlist /mnt/etc/pacman.d/mirrorlist

dd if=/dev/zero of=/mnt/swapfile bs=1M count=3072 status=progress
chmod 600 /mnt/swapfile
mkswap /mnt/swapfile
swapon /mnt/swapfile

genfstab -U /mnt >> /mnt/etc/fstab

customize-pacman-conf /mnt/etc/pacman.conf

echo -e "
#!/usr/bin/bash

systemctl enable NetworkManager

ln -sf /usr/share/zoneinfo/Asia/Kolkata /etc/localtime
hwclock --systohc

sed -i 's/#en_IN/en_IN/' /etc/locale.gen
locale-gen
echo \"LANG=en_IN.UTF-8\" >> /etc/locale.conf

grep '# %wheel' /etc/sudoers | grep -q -v 'NOPASSWD' &&
sed -i \"\$(grep -n '# %wheel' /etc/sudoers | grep -v 'NOPASSWD' | cut -d: -f1)s/# //\" /etc/sudoers
grep '# %sudo' /etc/sudoers | grep -q -v 'NOPASSWD' &&
sed -i \"\$(grep -n '# %sudo' /etc/sudoers | grep -v 'NOPASSWD' | cut -d: -f1)s/# //\" /etc/sudoers

sed -i 's/#GRUB_DISABLE_OS_PROBER=false/GRUB_DISABLE_OS_PROBER=false/' /etc/default/grub
sed -i 's/GRUB_TIMEOUT=5/GRUB_TIMEOUT=3/' /etc/default/grub
grub-install --bootloader-id=${BOOTLOADER_ID} --efi-directory=/boot/efi/ --target=x86_64-efi
grub-mkconfig -o /boot/grub/grub.cfg

echo \"${RTPASSWD}\n${RTPASSWD}\n\" | passwd
useradd -m -U -G wheel,network,scanner,power,audio,disk,input,video ${USER_NAME}
echo \"${PASSWORD}\n${PASSWORD}\n\" | passwd ${USER_NAME}

echo ${HOST_NAME} > /etc/hostname
echo \"127.0.0.1 localhost ${HOST_NAME}\" >> /etc/hosts

" > /mnt/afterscript.sh

if [ -n "${display_mgr}" ]
then
  echo "systemctl enable ${display_mgr}.service" >> /mnt/afterscript.sh
fi

arch-chroot /mnt sh afterscript.sh

rm /mnt/afterscript.sh

umount /mnt/boot/efi
umount /mnt

echo
echo
echo "I don't know why but for some reasons os-prober is not detecting windows OS"
echo "So, you've to run the following command after restart"
echo "            sudo grub-mkconfig -o /boot/grub/grub.cfg"
echo "Now, simply restart the pc"
