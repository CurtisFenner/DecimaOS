[bits 16]
[org 0x7c00]

KERNEL_SPAWN equ 0x9000

mov [BOOT_DRIVE], dl ; BIOS stores the booting drive in dl

mov bp, 0x8000 ; Move stack to safe spot
mov sp, bp


mov bx, MSG_REAL_MODE
call print_string

mov bx, KERNEL_SPAWN
mov dh, 10 ; Load 10 sectors to 
mov dl, [BOOT_DRIVE] ; dl already stores boot drive from BIOS
call disk_load

mov bx, KERNEL_SPAWN
mov dx, [bx]
call print_hex ; Print a call instruction...

jmp switch_to_pm

%include "print.asm"
%include "diskload.asm"
%include "gdt.asm"

switch_to_pm:
	cli
	lgdt [gdt_descriptor]

	mov eax, cr0
	or eax, 0x1
	mov cr0, eax

	jmp CODE_SEG:init_pm

[bits 32]

init_pm:
	mov ax, DATA_SEG
	mov ds, ax
	mov ss, ax
	mov es, ax
	mov fs, ax
	mov gs, ax

	mov ebp, 0x90000
	mov esp, ebp
	jmp protected_mode

protected_mode:
	mov ebx, MSG_PROT_MODE
	call print_string32
	; call kernel; A function defined by generate C kernel code
	jmp KERNEL_SPAWN
	jmp $

%include "print32.asm"


BOOT_DRIVE: db 0

MSG_REAL_MODE:
	db 'Decima is bootloader reached.', 10 , 13, 0

MSG_PROT_MODE:
	db 'Decima in 32. Jumping to kernel...', 0

times 510 - ($ - $$) db 0
dw 0xaa55 ; Mark bootable segment

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;