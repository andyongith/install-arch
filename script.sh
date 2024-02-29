#!/usr/bin/bash

### Taking User Inputs
#
all_partitions=($(blkid | cut -d: -f1))
select_partition() {
  for partition in "${all_partitions[@]}"
  do
    if $(echo "$@" | grep -q $partition)
    then
      avail_partitions=( "${avail_partitions[@]}" "" )
    else
      avail_partitions=( "${avail_partitions[@]}" "${partition}" )
    fi
  done
  select partition in "${avail_partitions[@]}"
  do
    if [ -n "$partition" ]
    then
      echo ${partition}
      break
    fi
  done
}

confirmed="no"
while [ "$confirmed" != "yes" ]
do
  clear
  echo "Choose EFI partition: "
  ESP=$(select_partition)
  echo
  echo "Choose Root partition: "
  ROOT=$(select_partition $ESP)
  # echo
  # echo "Choose Swap partition: "
  # SWAP=$(select_partition $ESP $ROOT)
  
  clear
  echo ESP: $ESP
  echo root: $ROOT
  # echo swap: $SWAP
  echo
  echo "Confirmed: "
  select confirmed in "yes" "no"
  do
    if [ -n "$confirmed" ]
    then
      break
    fi
  done
done

confirmed="no"
while [ $confirmed = "no" ]
do
  clear
  echo -n "Enter root password: "
  read RTPASSWD
  echo
  echo -n "Enter username: "
  read USERNAME
  echo -n "Enter password: "
  read  PASSWORD
  echo
  echo -n "Enter hostname: "
  read HOSTNAME
  echo
  echo "Confirmed: "
  select confirmed in "yes" "no"
  do
    if [ -n "$confirmed" ]
    then
      break
    fi
  done
done


confirmed="no"
while [ $confirmed = "no" ]
do
  display_mgr=
  setup_pkg=
  extra_pkg=
  clear
  echo "Choose your GUI setup"
  select setup in "My_setup(xorg gnome gnome-extra gdm)" "Minimal"
  do
    case $REPLY in
      1)
        display_mgr=gdm
        setup_pkg=( xorg gnome gnome-extra gdm )
        break
        ;;
      2)
        break
        ;;
    esac
  done

  echo
  echo "Extra packages to install(separated by white space): "
  read extra_pkg

  clear
  echo display manager: $display_mgr
  echo extra packages : ${setup_pkg[@]} ${extra_pkg[@]}
  echo
  echo "Confirmed: "
  select confirmed in "yes" "no"
  do
    if [ -n "$confirmed" ]
    then
      break
    fi
  done
done


### Installation
#
mkfs.vfat -F32 -n "ESP" $ESP
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
reflector --latest 10 --sort rate --save /etc/pacman.d/mirrorlist
pacman -Sy --noconfirm archlinux-keyring
pacstrap /mnt/ \
  base base-devel \
  linux-lts linux-firmware linux-lts-headers \
  efibootmgr grub os-prober \
  intel-ucode amd-ucode \
  exfat-utils \
  networkmanager \
  vi vim \
  reflector \
  man-db git ${setup_pkg[@]} ${extra_pkg[@]} \
  --noconfirm --needed
cp /etc/pacman.d/mirrorlist /mnt/etc/pacman.d/mirrorlist

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
grub-install --bootloader-id=Arch --efi-directory=/boot/efi/ --target=x86_64-efi
grub-mkconfig -o /boot/grub/grub.cfg

echo \"${RTPASSWD}\n${RTPASSWD}\n\" | passwd
useradd -m -U -G wheel,network,scanner,power,audio,disk,input,video ${USERNAME}
echo \"${PASSWORD}\n${PASSWORD}\n\" | passwd ${USERNAME}

echo ${HOSTNAME} > /etc/hostname
echo \"127.0.0.1 localhost ${HOSTNAME}\" >> /etc/hosts

" > /mnt/afterscript.sh

if [ -n "${display_mgr}" ]
then
  echo "systemctl enable ${display_mgr}.service" >> /mnt/afterscript.sh
fi

arch-chroot /mnt sh afterscript.sh

rm /mnt/afterscript.sh

umount /mnt/boot/efi
umount /mnt
