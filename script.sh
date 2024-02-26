#!/usr/bin/bash

echo -n root partition\(e.g. /dev/sda2\) : 
read ROOT

echo -n EFI partition\(e.g. /dev/sda1\) : 
read ESP

mkfs.vfat -F32 -n "ESP" $ESP
mkfs.ext4 -L "Arch-root" $ROOT

mkdir -p /mnt/boot/efi
mount $ROOT /mnt/
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

reflector --latest 5 --sort rate --save /etc/pacman.d/mirrorlist
cp /etc/pacman.d/mirrorlist /mnt/etc/pacman.d/mirrorlist
pacman -Sy
pacstrap /mnt/ \
  base base-devel \
  linux-lts linux-firmware linux-lts-headers \
  efibootmgr grub os-probe \
  exfat-utils \
  networkmanager \
  vi vim \
  reflector \
  --noconfirm --needed

genfstab -U /mnt >> /mnt/etc/fstab

customize-pacman-conf /mnt/etc/pacman.conf

echo -e "
#!/usr/bin/bash

systemctl enable NetworkManager

ln -sf /usr/share/zoneinfo/Asia/Kolkata /etc/localtime
hwclock --systohc

sed -i 's/#en_IN/en_IN/' /etc/locale.gen
locale-gen
echo \"LANG=en_IN.UTF-8\"

sed -i 's/#%wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/ /etc/sudoers
sed -i 's/#%sudo ALL=(ALL:ALL) ALL/%sudo ALL=(ALL:ALL) ALL/ /etc/sudoers

sed -i 's/#GRUB_DISABLE_OS_PROBER=false/GRUB_DISABLE_OS_PROBER=false'
grub-install --bootloader-id=Arch --efi-directory=/boot/efi/ --target=x86_64-efi
grub-mkconfig -o /boot/grub/grub.cfg

echo
echo Now, enter the root password...
passwd

" > /mnt/afterscript.sh

arch-chroot /mnt sh afterscript.sh