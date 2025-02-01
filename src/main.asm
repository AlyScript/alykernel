org 0x7C00 ; BIOS loads the bootloader at 0x7C00
bits 16    ; 16 bit mode for backward compatibility

main:
    
    ; Set up data segments
    mov ax, 0
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax

    ; Set up stack
    mov ss, ax 
    mov sp, 0x7C00 ; Stack pointer is at beginning of bootloader (it grows downwards)
    
    hlt

.halt:
    jmp .halt

; 0x55AA is the magic number for the bootloader
; BIOS Expects that the last 2 bytes of 512 byte sector is 0x55AA
; So we pad the rest with 510 bytes
times 510 - ($ - $$) db 0
dw 0AA55h