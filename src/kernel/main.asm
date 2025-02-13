org 0x0     ; BIOS loads the bootloader at 0x7C00
bits 16     ; 16 bit mode for backward compatibility

%define ENDL 0x0D, 0x0A

start:
    ; print message
    mov si, msg_hello
    call puts

.halt:
    cli
    hlt


; Print a string to the screen
; Params:
;   ds:si is a pointer to a string

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

msg_hello: db 'Hello, World from Kernel!', ENDL, 0


