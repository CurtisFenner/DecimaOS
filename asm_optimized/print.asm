print_string: 
	pusha 
mov ah, 0x0e
	.loop: 
mov al, [bx]
		cmp al, 0 
		je .done  ;  Null terminated output
		int 0x10 
add bx, 1
		jmp .loop 
	.done: 
	popa 
	ret 
print_hex: 
	pusha 
mov bx, dx
	and bx, 0x000f 
add bx, .hexes
mov bx, [bx]
mov [.hex_out + 3], bl
	shr dx, 4 
mov bx, dx
	and bx, 0x000f 
add bx, .hexes
mov bx, [bx]
mov [.hex_out + 2], bl
	shr dx, 4 
mov bx, dx
	and bx, 0x000f 
add bx, .hexes
mov bx, [bx]
mov [.hex_out + 1], bl
	shr dx, 4 
mov bx, dx
	and bx, 0x000f 
add bx, .hexes
mov bx, [bx]
mov [.hex_out + 0], bl
mov bx, .hex_prefix
	call print_string 
	popa 
	ret 
.hexes: 
	db '0123456789abcdef' 
.hex_prefix: 
	db '0x' 
.hex_out: 
	db '0000', 0 
