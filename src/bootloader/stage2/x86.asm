bits 16

section _TEXT class=CODE

;
; void _cdecl x86_div64_32(uint64_t dividend, uint32_t divisor, uint64_t* quotientOut, uint32_t* remainderOut);
;
global _x86_div64_32
_x86_div64_32:

    ; new stack frame
    push bp        ; save old call frame
    mov bp, sp     ; initialise new call frame

    push bx

    ; divide upper 32 bits
    mov eax, [bp + 4]        ; eax <- upper 32 bits of divident
    mov ecx, [bp + 12]       ; ecx <- divisor
    xor edx, edx            ; clear edx
    div ecx                 ; eax = eax / ecx, edx = eax % ecx

    ; store upper 32 bits of quotient
    mov ebx, [bp + 16]
    mov [bx + 4], eax

    ; divide lower 32 bits
    mov eax, [bp + 4]        ; eax <- lower 32 bits of divident
                             ; edx <- old remainder
    div ecx

    ; store lower 32 bits of quotient
    mov [bx], eax
    mov bx, [bp + 18]
    mov [bx], edx           ; store remainder                 

    pop bx

    ; restore old stack frame
    mov sp, bp
    pop bp
    ret

global _x86_Video_WriteCharTeletype             ; '_' character is prefixed to names when using CDECL calling convention
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