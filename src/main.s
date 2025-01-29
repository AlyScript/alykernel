.global _start
.section .text
.half

_start:
    wfi

halt:
    jal halt

# 0x55AA is the magic number for the bootloader
# BIOS Expects that the last 2 bytes of 512 byte sector is 0x55AA
# So we pad the rest with 510 bytes
.space 510 - (.-_start)
.byte 0x55
.byte 0xAA