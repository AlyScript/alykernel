## Setting up the environment

A dockerfile has been created with all of the dependencies required to build and run the kernel. Only qemu needs to be installed natively. The method for doing this will differ depending on what your Host OS is.

`docker build -t riscv-env .` to create the image.

`docker run --rm -it -v $(pwd):/workspace riscv-env` to run the container.

Then you can run `make` to build the project.

qemu was used to run the image, if you would like to do the same then I reccomend that you run it natively.
`qemu-system-i386 -fda build/main_floppy.img` will boot the kernel.

## Some Background
# Booting
The kernel boots via legacy BIOS booting from a floppy disk (typically 1.44 MB in size). The BIOS loads the boot sector at address 0x7C00 and we have 512 bytes to work with.
It also expects that the last two bytes of the 512 byte sector are AA and 55 respectively.

# File Systems
Our BIOS unfortunately uses Cylinder-head-sector (CHS) addressing to give addresses to each physical block of data on the floppy disk.
This is very outdated and unnecessary for our purposes, so instead we make use of Logical Block Addressing (LBA). We therefore need a way of conversing a LBA to a CHS address. The formula for doing this is well known
    - C = LBA ÷ (HPC × SPT)
    - H = (LBA ÷ SPT) mod HPC
    - S = (LBA mod SPT) + 1
where
    - C, H and S are the cylinder number, the head number, and the sector number
    - LBA is the logical block address
    - HPC is the maximum number of heads per cylinder (reported by disk drive, typically 16 for 28-bit LBA)
    - SPT is the maximum number of sectors per track (reported by disk drive, typically 63 for 28-bit LBA)

# A Note on FAT12
The File Allocation Table (FAT) was the native file system of MS-DOS.

alykernel makes use of the simple FAT12 file system, since it is by far the most simple. As a result, the floppy disk must be organized into three basic areas.
    - The boot record
    - The File Allocation Table (FAT)
    - The directory and data area

The `GNU Mtools` package (one of the dependencies in the dockerfile) provides a number of utilities that can be used for manipulating files in the FAT12 filesystem.

# Memory Addressing
