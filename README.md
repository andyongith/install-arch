# Install-arrch

As the name suggests this is an installation-script for Arch linux.

## How to use?
To use this script in the live installation-environment, first make 2 partitions:    
 * root partition where yours OS'll be installed (preferred size >= 20MiB)
 * efi partiotion where your Bootloader will be installed (preferred size = 1Gib) 

and then run the following commands...
```
curl https://raw.githubusercontent.com/andyongith/install-arch/main/script.sh -o install-script.sh

chmod +x install-script.sh

./install.sh
```
then enter the required fields, and you're good to go.

## To-do list(For me)
 * Make it add more users