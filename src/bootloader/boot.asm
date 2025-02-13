org 0x7C00 ; BIOS loads the bootloader at 0x7C00
bits 16    ; 16 bit 'real' mode for backward compatibility

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
dir_entry_count:             dw 0E0h    ; 224 entries in root directory - 224 * 32 bytes = 7168 bytes (14 sectors)
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

;
; Code goes here
;

main:
    
    ; Set up data segments
    mov ax, 0
    mov ds, ax
    mov es, ax

    ; Set up stack
    mov ss, ax
    mov sp, 0x7C00 ; Stack pointer is at beginning of bootloader (it grows downwards)

    ; Some BIOSes may start us at 07C0:0000, so we need to jump to 0000:7C00, this ensures that
    ; we are in the correct segment
    push es
    push word .after

.after:

    ; Read the first sector of the disk
    ; BIOS should set dl to the drive number
    mov [ebr_physical_drive_number], dl

    mov ax, 1           ; LBA address of the first sector
    mov cl, 1           ; number of sectors to read
    mov bx, 0x7E00      ; memory address where to store the data - this should be after bootloader
    call disk_read
    
    ; print message
    mov si, msg_loading
    call puts

    cli
    hlt

;
; Error handlers
;

floppy_error:
    mov si, msg_read_error
    call puts
    jmp wait_key_and_reboot

wait_key_and_reboot:
    mov ah, 0           ; read keyboard input
    int 16h             ; wait for key press
    jmp 0FFFFh:0000h    ; jump to beginning of BIOS, rebooting the system

.halt:
    cli                 ; disable interrupts so we cant get out of half state
    jmp .halt


; Print a string to the screen
; Params:
;   ds;si is a pointer to a string
puts:
    ; push registers
    push si
    push ax
.loop:
    lodsb               ; load next character into al
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

;
; https://stanislavs.org/helppc/int_13-2.html
; Read sectors from disk
; Params:
;   - ax = LBA address
;   - cl: number of sectors to read (up to 128)
;   - dl: drive number
;   - es:bx: memory address where to store and read data
disk_read:
    push ax                             ; save registers
    push bx
    push cx
    push dx
    push di

    push cx                             ; temoporarily save CL (number of sectors to read)
    call lba_to_chs                     ; convert LBA to CHS
    pop ax                              ; AL = number of sectors to read (top of stack was CL)

    mov ah, 02h                          ; BIOS read sector function
    mov di, 3                            ; number of retries

.retry:
    pusha                               ; save registers - we don't know what the BIOS will change
    stc                                 ; set carry flag, as per BIOS documentation some BIOSes don't set it
    int 13h                             ; call BIOS interrupt
    jnc .success                        ; if carry flag is not set, we are good

    ; read failed
    popa
    call disk_reset                     ; reset disk
    
    dec di
    test di, di
    jnz .retry

.fail:
    ; after all attempts are exhausted
    jmp floppy_error

.success:
    popa

    pop di                             ; save registers
    pop dx
    pop cx
    pop bx
    pop ax
    ret

;
;
;
disk_reset:
    pusha
    mov ah, 0                           ; reset disk
    stc                                 ; set carry flag
    int 13h                             ; call BIOS interrupt
    jc floppy_error                     ; if carry flag is set, we have an error     
    popa
    ret


msg_loading:      db 'Loading', ENDL, 0
msg_read_error: db 'Error reading disk!', ENDL, 0

; 0x55AA is the magic number for the bootloader
; BIOS Expects that the last 2 bytes of 512 byte sector is 0x55AA
; So we pad the rest with 510 bytes
times 510 - ($ - $$) db 0
dw 0AA55h
