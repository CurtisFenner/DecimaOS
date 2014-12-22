; Load DH sectors to ES:BX from drive DL

; es:bx is where disc contents are written to
; dh is number of sectors (512B sections) to read
; dl is which disc to load from
disk_load:
	push dx ; We will want to know how many were requested
	mov ah, 0x02 ; Read sector function.
	mov al, dh ; Read DH sectors
	mov ch, 0x00 ; Cylinder 0
	mov dh, 0x00 ; Head 0
	mov cl, 0x02 ; Start reading at sector 2
		; (content after boot sector)

	int 0x13 ; BIOS disk interrupt

	jc disk_error_general ; Jump on error

	pop dx
	cmp dh, al ; AL (sectors read) != DH (sectors requested)
	jne disk_error_sectors;

	ret

disk_error_general:
	mov bx, DISK_ERROR_GENERAL_MESSAGE
	call print_string
	jmp $

disk_error_sectors:
	mov bx, DISK_ERROR_SECTORS_MESSAGE
	call print_string
	jmp $

got:
db "cat", 0

DISK_ERROR_GENERAL_MESSAGE db "Disk error (Gen. failure)", 0
DISK_ERROR_SECTORS_MESSAGE db "Disk error (Too few sectors read)", 0