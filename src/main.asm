org 0x7C00 ; BIOS loads the bootloader at 0x7C00
bits 16    ; 16 bit mode for backward compatibility

main:
    hlt

.halt:
    jmp .halt

; 0x55AA is the magic number for the bootloader
; BIOS Expects that the last 2 bytes of 512 byte sector is 0x55AA
; So we pad the rest with 510 bytes
times 510 - ($ - $$) db 0
dw 0AA55h