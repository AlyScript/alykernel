bits 16

section _TEXT class=CODE

global _x86_Video_WriteCharTeletype
_x86_Video_WriteCharTeletype:
    
    ; make new stack frame
    push bp         ; save old call frame
    mov bp, sp      ; initialise new call frame

    ; save bx (CDECL says its callee-saved)
    push bx

    ; [bp + 0] = old call frame
    ; [bp + 2] = return address
    ; [bp + 4] = first argument (character): bytes are converted to words -- stack must be word aligned
    ; [bp + 6] = second argument (page)
    mov ah, 0x0E
    mov al, [bp + 4]
    mov bh, [bp + 6]

    int 0x10                    ; int 10,E - teletype output https://stanislavs.org/helppc/int_10-e.html

    pop bx                      ; restore bx

    ; restore old stack frame
    mov sp, bp
    pop bp
    ret