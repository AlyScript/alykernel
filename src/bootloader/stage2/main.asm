bits 16

section _ENTRY class=CODE

extern _cstart_
global entry

entry:
    cli
    ; setup stack
    mov ax, ds
    mov ss, ax
    mov sp, 0
    mov bp, sp
    sti

    ; expect boot drive in dl, so send it as an argument to cstart function
    xor dh, dh
    push dx
    call _cstart_

    cli
    hlt
