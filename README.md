## Setting up the environment

A dockerfile has been created with all of the dependencies required to build and run the kernel. Only qemu needs to be installed natively. The method for doing this will differ depending on what your Host OS is.

`docker build -t riscv-env .` to create the image.

`docker run --rm -it -v $(pwd):/workspace riscv-env` to run the container.

Then you can run `make` to build the project.

qemu was used to run the image, if you would like to do the same then I reccomend that you run it natively.
`qemu-system-i386 -fda build/main_floppy.img` will boot the kernel.

## Some Background
# Booting
The kernel boots via legacy BIOS booting from a floppy disk. The BIOS loads the boot sector at address 0x7C00 and we have 512 bytes to work with.
It also expects that the last two bytes of the 512 byte sector are AA and 55 respectively.

# Memory Addressing
