org 0x7C00 ; BIOS loads the bootloader at 0x7C00
bits 16    ; 16 bit mode for backward compatibility

%define ENDL 0x0D, 0x0A

start:
    jmp main


; Print a string to the screen
; Params:
;   ds;si is a pointer to a string
puts:
    ; push registers
    push si
    push ax
.loop:
    lodsb               ; load next charcter into al
    or al, al           ; check if al is 0 (end of string)
    jz .done

    mov ah, 0x0E        ; teletype output
    mov bh, 0x00        ; page number
    int 0x10            ; call BIOS interrupt

    jmp .loop

.done:
    ; pop registers
    pop ax
    pop si
    ret


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
    
    ; print message
    mov si, msg_hello
    call puts

    hlt

.halt:
    jmp .halt

msg_hello: db 'Hello, World!', ENDL, 0

; 0x55AA is the magic number for the bootloader
; BIOS Expects that the last 2 bytes of 512 byte sector is 0x55AA
; So we pad the rest with 510 bytes
times 510 - ($ - $$) db 0
dw 0AA55h
