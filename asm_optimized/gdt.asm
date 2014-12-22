gdt_start: 
gdt_null:  ;  The mandatory null descriptor
	dd 0x0  ;  dd is double-word (4 byte pieces)
	dd 0x0  ;  So two of them = the 8 byte mandatory 0
gdt_code:  ;  The code segment descriptor (of Intel "flat model")
	dw 0xffff  ;  Limit
	dw 0x0  ;  Base (bits 0 to 15)
	db 0x0  ;  Base continued (bits 16 to 23)
	db 10011010b  ;  1st flags, type flags
	db 11001111b  ;  2nd flags, limit
	db 0x0  ;  Base (24 - 31)
gdt_data:  ;  Data segment descriptor (of Intel "flat model")
	dw 0xffff  ;  Limit (0 - 15)
	dw 0x0  ;  Base (0 - 15)
	db 0x0  ;  Base (16 - 32)
	db 10010010b  ;  1st flags, type flags
	db 11001111b  ;  2nd flags, limit (16 - 19)
	db 0x0  ;  Base (24 - 31)
gdt_end:  ;  For calculating GDT size for GDT descriptor
gdt_descriptor:  ;  The GDT descriptor
	dw gdt_end - gdt_start - 1  ;  Size of GDT
	dd gdt_start  ;  Start of the GDT
CODE_SEG equ gdt_code - gdt_start 
DATA_SEG equ gdt_data - gdt_start 
