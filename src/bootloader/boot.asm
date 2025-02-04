org 0x7C00 ; BIOS loads the bootloader at 0x7C00
bits 16    ; 16 bit mode for backward compatibility

%define ENDL 0x0D, 0x0A

; 
; FAT12 Header (A.K.A BIOS Parameter Block)
; See FAT12 specification for more information
; 
jmp short start
nop

bdb_oem:                     db "MSWIN4.1"
bdb_bytes_per_sector:        dw 512
bdb_sectors_per_cluster:     db 1
bdb_reserved_sectors:        dw 1
bdb_fat_count:               db 2
dir_entry_count:             dw 0E0h
bdb_total_sectors:           dw 2880    ; 2880 * 512B Sectors = 1.44MB (The size of a floppy disk)
bdb_media_descriptor:        db 0F0h
bdb_sectors_per_fat:         dw 9
bdb_sectors_per_track:       dw 18
bdb_head_count:              dw 2
bdb_hidden_sectors:          dd 0
bdb_total_sectors_big:       dd 0

; Extended Boot Record (Again for FAT12)
ebr_physical_drive_number:  db 0       ; 0x80 for hard drive, 0x00 for floppy
ebr_reserved:               db 0
ebr_ext_boot_signature:     db 29h
ebr_volume_id:              dd 0
ebr_volume_label:           db "ALYKERNEL  "
ebr_file_system:            db "FAT12   "


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

;
; Disk Routines
;

; Converts an LBA address to CHS
; Params:
;   ax = LBA address
; Returns:
;   - cx [bits 0:5]: sector number
;   - cx [bits 6:15]: cylinder number
;   - dh: head number

lba_to_chs:

    ; Note that cl and ch contain the 8 lower and 8 upper bits of cx in x86
    ; So we can use them to store the cylinder number

    push ax
    push dx

    xor dx, dx                          ; Clear dx
    div word [bdb_sectors_per_track]    ; ax = LBA / SPT
                                        ; dx = LBA % SPT

    inc dx                              ; dx = (LBA % SPT) + 1 = sector
    mov cx, dx                          ; cx = sector

    xor dx, dx                          ; Clear dx
    div word [bdb_head_count]           ; ax = LBA / (SPT * HPC) = cylinder
                                        ; dx = LBA % (SPT * HPC) = head

    mov dh, dl                          ; dh = head
    mov ch, al                          ; ch = cylinder low byte (lower 8 bits)
    shl ah, 6                           ; ah = cylinder high byte (upper 2 bits)
    or cl, ah                           ; put the upper 2 bits of cylinder into cl

    pop ax
    mov dl, al                          ; we only restore dl
    pop ax
    ret

msg_hello: db 'Hello, World!', ENDL, 0

; 0x55AA is the magic number for the bootloader
; BIOS Expects that the last 2 bytes of 512 byte sector is 0x55AA
; So we pad the rest with 510 bytes
times 510 - ($ - $$) db 0
dw 0AA55h
