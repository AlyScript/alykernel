<img src="https://i.imgur.com/Jo7l9Q1.png" alt="logo" width="500">

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
  docker run --rm -it -v $(pwd):/workspace riscv-env
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
  qemu-system-i386 -fda build/main_floppy.img
```


## Appendix

### Booting
The kernel boots via legacy BIOS booting from a floppy disk (typically 1.44 MB in size). The BIOS loads the boot sector at address `0x7C00` and we have 512 bytes to work with. It also expects that the last two bytes of the 512 byte sector are AA and 55 respectively.

### File Systems
Our BIOS unfortunately uses [Cylinder-head-sector](https://en.wikipedia.org/wiki/Cylinder-head-sector) (CHS) addressing to give addresses to each physical block of data on the floppy disk.
This is very outdated and unnecessary for our purposes, so instead we make use of [Logical Block Addressing](https://en.wikipedia.org/wiki/Logical_block_addressing) (LBA). We therefore need a way of conversing a LBA to a CHS address. The formula for doing this is well known
- C = LBA ÷ (HPC × SPT)
- H = (LBA ÷ SPT) mod HPC
- S = (LBA mod SPT) + 1
where
- C, H and S are the cylinder number, the head number, and the sector number
- LBA is the logical block address
- HPC is the maximum number of heads per cylinder (reported by disk drive, typically 16 for 28-bit LBA)
- SPT is the maximum number of sectors per track (reported by disk drive, typically 63 for 28-bit LBA)

### A note on FAT12
The [File Allocation Table](https://wiki.osdev.org/FAT) (FAT) was the native file system of MS-DOS.

alykernel makes use of the simple FAT12 file system, since it is by far the most simple. As a result, the floppy disk must be organized into three basic areas.
- The boot record
- The File Allocation Table (FAT)
- The directory and data area

The [mtools](https://www.gnu.org/software/mtools/) package (one of the dependencies in the dockerfile) provides a number of utilities that can be used for manipulating files in the FAT12 filesystem.