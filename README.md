<img src="https://i.imgur.com/Jo7l9Q1.png" alt="logo" width="1000">

alykernel is a simple kernel designed for the x86 architecture.


## Run Locally

Clone the project

```bash
  git clone https://github.com/alyscript/alykernel
```

Go to the project directory

```bash
  cd alykernel
```

Build the docker image

```bash
  docker build -t riscv-env .
```

Run the container

```bash
  docker run --rm -it -v $(pwd):/alykernel riscv-env
```

Build the project
```bash
  make
```

To the clean the build directory
```bash
  make clean
```

You can now boot alykernel! To do this using [qemu](https://www.qemu.org/)
```bash
  ./run.sh
```


## Appendix

### Booting
The bootloader has three primary roles:
1. Collect information
2. Put the system in the state expected by the kernel
3. Load and execute the kernel

The kernel boots via [legacy BIOS booting](https://wiki.osdev.org/System_Initialization_(x86)) from a floppy disk (typically 1.44 MB in size). The BIOS loads the boot sector into memory at address `0x7C00` and we have 512 bytes (1 Sector) to work with (which is not a lot). It also expects that the last two bytes of the 512 byte sector are AA and 55 respectively.

There are very few things that are standardized about the state of the system, when the BIOS transfers control to the bootsector. The only things that are (nearly) certain are that the bootsector code is loaded and running at physical address 0x7c00, the CPU is in 16-bit [Real Mode](https://wiki.osdev.org/Real_Mode), the CPU register called DL contains the "drive number", and that only 512 bytes of the bootsector have been loaded.

#### Loading the Kernel
We need to swith to 64 bit [protected mode](https://wiki.osdev.org/Protected_Mode) in order to take advantage of the CPU's resources.
The kernel is loaded at physical address 0x20000. 

#### Memory Map
The real mode address space is less than 1 MiB and the bootloader code is loaded and running in memory at physical addresses 0x7C00 to 0x7DFF so that memory area is unusable until execution has been transferred to the kernel.
[This page](https://wiki.osdev.org/Memory_Map_(x86)#Real_mode_address_space_(%3C_1_MiB)) shows the entire memory map of the real mode address space for those interested.

### File Systems
Our BIOS uses [Cylinder-head-sector](https://en.wikipedia.org/wiki/Cylinder-head-sector) (CHS) addressing to give addresses to each physical block of data on the floppy disk.
This is very outdated and unnecessary for our purposes, so instead we make use of [Logical Block Addressing](https://en.wikipedia.org/wiki/Logical_block_addressing) (LBA). We therefore need a way of conversing a LBA to a CHS address. The formula for doing this is well known
- C = LBA ÷ (HPC × SPT)
- H = (LBA ÷ SPT) mod HPC
- S = (LBA mod SPT) + 1

where
- C, H and S are the cylinder number, the head number, and the sector number
- LBA is the logical block address
- HPC is the maximum number of heads per cylinder (reported by disk drive, typically 16 for 28-bit LBA)
- SPT is the maximum number of sectors per track (reported by disk drive, typically 63 for 28-bit LBA)

To actually carry out the read from the disk, we need to call the BIOS Interrupt [INT 13, 2](https://stanislavs.org/helppc/int_13-2.html).

### A note on FAT12
The [File Allocation Table](https://wiki.osdev.org/FAT) (FAT) was the native file system of MS-DOS.

alykernel makes use of the simple FAT12 file system, since it is by far the most simple. As a result, the floppy disk must be organized into three basic areas.
- The boot record
- The File Allocation Table (FAT)
- The directory and data area

The [mtools](https://www.gnu.org/software/mtools/) package (one of the dependencies in the dockerfile) provides a number of utilities that can be used for manipulating files in the FAT12 filesystem.
