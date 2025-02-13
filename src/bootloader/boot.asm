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

start:
    
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
    
    ; print message
    mov si, msg_loading
    call puts

    ; Read drive parameters (sectors per track and head count)
    ; instead of relying on data from formatted disk
    push es
    mov ah, 08h
    int 13h                                 ; see https://www.stanislavs.org/helppc/int_13-8.html
    jc floppy_error
    pop es

    and cl, 0x3F                             ; remove two leftmost bits, since we only need bits 0-5 for sector number
    xor ch, ch                               ; clear ch, since we only need bits 6-15 for cylinder number
    mov [bdb_sectors_per_track], cx

    inc dh
    mov [bdb_head_count], dh

    ; computer LBA of root directory = reserved + fats * sectors per fat
    mov ax, [bdb_sectors_per_fat]
    mov bl, [bdb_fat_count]
    xor bh, bh                               ; we only want the lower 8 bits of bl
    mul bx                                   ; fats * sectors per fat
    add ax, [bdb_reserved_sectors]           ; reserved + fats * sectors per fat
    push ax                                  ; save LBA of root directory

    ; compute the size of the root directory in sectors
    mov ax, [bdb_sectors_per_fat]
    shl ax, 5                                ; ax = sectors per fat * 32 (32 bytes per directory entry)
    xor dx, dx                               ; clear dx for division (remainder goes here)         
    div word [bdb_bytes_per_sector]          ; ax = sectors per fat * 32 / bytes per sector

    test dx, dx                              ; check if there is a remainder
    jz root_dir_after
    inc ax                                   ; if there is a remainder, we need an extra sector     

root_dir_after:

    ; read root directory
    mov cl, al                               ; cl = number of sectors to read = size of root directory
    pop ax                                   ; ax = LBA of root directory 
    mov dl, [ebr_physical_drive_number]      ; dl = drive number (we saved it previously)
    mov bx, buffer                           ; es:bx = buffer
    call disk_read

    ; search for kernel.bin
    xor bx, bx                               ; bx = 0
    mov di, buffer                           ; di points to the current directory entry  (filename field is first entry so di will point directly to it)

.search_kernel:
    mov si, file_kernel_bin                  ; si points to the filename we are looking for
    mov cx, 11                               ; we are looking for 11 characters
    push di
    repe cmpsb                               ; while CX != 0, Compare byte at address DS:(E)SI with byte at address ES:(E)DI
    pop di
    je .found_kernel                         ; if we found the kernel, jump to .found_kernel

    add di, 32                               ; move to the next directory entry
    inc bx                                   ; increment the number of entries we have checked
    cmp bx, [dir_entry_count]                ; check if we have checked all entries
    jl .search_kernel                        ; if we havent checked all entries, jump to .search_kernel

    jmp kernel_not_found_error

.found_kernel:

    ; di should have the address to the entry of the kernel
    mov ax, [di + 26]                       ; get the starting cluster of the kernel (see in the FAT12 specification) by offsetting di by 26 bytes
    mov [kernel_cluster], ax                

    ; now load FAT from disk into memory
    ; all we need to do is set up the correct parameters and call disk_read
    mov ax, [bdb_reserved_sectors]         
    mov bx, buffer
    mov cl, [bdb_sectors_per_fat]          
    mov dl, [ebr_physical_drive_number]
    call disk_read

    ; read kernel and process FAT chain
    mov bx, KERNEL_LOAD_SEGMENT
    mov es, bx
    mov bx, KERNEL_LOAD_OFFSET

.load_kernel_loop:
    ; Read next cluster
    mov ax, [kernel_cluster]

    ; this is bad :0 and hardcoded... i will fix it soon
    add ax, 31                              ; first cluster = (kernel cluster number - 2) * sectors per cluster + kernel_cluster  
                                            ; start sector = reserved + fats + root directory size = 1 + 18 * 14 = 33

    mov cl, 1
    mov dl, [ebr_physical_drive_number]
    call disk_read

    add bx, [bdb_bytes_per_sector]

    ; compute location of next cluster
    mov ax, [kernel_cluster]
    mov cx, 3
    mul cx                                  ; multiply by 3 to get the index of the entry in FAT since each entry is 12 bits (1.5 bytes)
    mov cx, 2
    div cx                                  ; ax = index of the entry in FAT, dx = cluster mod 2

    mov si, buffer
    add si, ax
    mov ax, [ds:si]                         ; read entry from FAT table at index ax

    or dx, dx
    jz .even

.odd:
    shr ax, 4                               ; get the high 12 bits of the entry
    jmp .next_cluster_after

.even:
    and ax, 0x0FFF                          ; get the low 12 bits of the entry

.next_cluster_after:
    cmp ax, 0x0FF8                          ; check if we are at the end of the file
    jae .read_finish

    mov [kernel_cluster], ax
    jmp .load_kernel_loop

.read_finish:
    ; jump to kernel
    mov dl, [ebr_physical_drive_number]     ; boot device in dl

    ; set segment registers
    mov ax, KERNEL_LOAD_SEGMENT
    mov ds, ax
    mov es, ax

    jmp KERNEL_LOAD_SEGMENT:KERNEL_LOAD_OFFSET

    jmp wait_key_and_reboot                 ; if we are here, something went wrong    

.done:
    cli                                     ; disable interrupts so CPU cant get out of half state
    hlt


;
; Error handlers
;

floppy_error:
    mov si, msg_read_error
    call puts
    jmp wait_key_and_reboot

kernel_not_found_error:
    mov si, msg_kernel_not_found
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

; Resets disk controller
; Params:
;   dl: drive number
;
disk_reset:
    pusha
    mov ah, 0                           ; reset disk
    stc                                 ; set carry flag
    int 13h                             ; call BIOS interrupt
    jc floppy_error                     ; if carry flag is set, we have an error     
    popa
    ret


msg_loading:            db 'Loading', ENDL, 0
msg_read_error:         db 'Error reading disk!', ENDL, 0
msg_kernel_not_found:   db 'KERNEL.BIN file not found!', ENDL, 0
file_kernel_bin:        db 'KERNEL  BIN'
kernel_cluster:         dw 0

KERNEL_LOAD_SEGMENT     equ 0x2000
KERNEL_LOAD_OFFSET      equ 0


; 0x55AA is the magic number for the bootloader
; BIOS Expects that the last 2 bytes of 512 byte sector is 0x55AA
; So we pad the rest with 510 bytes
times 510 - ($ - $$) db 0
dw 0AA55h

buffer:                 