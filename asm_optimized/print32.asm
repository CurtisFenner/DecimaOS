[bits 32] 
VIDEO_MEMORY equ 0xb8000 
WHITE_ON_BLACK equ 0x0f 
print_string32: 
	pusha 
mov edx, VIDEO_MEMORY + 80 * 2 ;  Set edx to the start of vid mem.
.looe: 
mov al, [ebx] ;  Store the char at EBX in AL
mov ah, WHITE_ON_BLACK ;  Store the attributes in AH
	cmp al, 0  ;  Check if it's the NULL character (null terminating)
	je .done  ;  jump to done
mov [edx], ax ;  Store char and attributes at current
add ebx , 1 ;  Increment EBX to the next char in string.
add edx , 2 ;  Move to next character cell in vid mem.
	jmp .looe 
.done: 
	popa 
	ret  ;  Return from the function
hexes32: 
	db "0123456789ABCDEF" 
prehex32: 
	db "0x" 
hex32: 
	db "00000000", 0 
