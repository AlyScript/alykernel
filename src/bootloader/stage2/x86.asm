bits 16

section _TEXT class=CODE

global _x86_Video_WriteCharTeletype
_x86_Video_WriteCharTeletype:
    
    ; make new stack frame
    push bp         ; save old call frame
    mov bp, sp      ; initialise new call frame

    ; save bx (CDECL says its callee-saved)
    push bx

    ; [bp] = return address
    ; [bp + 2] = first argument (character): bytes are converted to words -- stack must be word aligned
    ; [bp + 4] = second argument (page)
    mov ah, 0x0E
    mov al, [bp + 2]
    mov bh, [bp + 4]

    int 0x10

    pop bx

    mov sp, bp
    pop bp
    ret