[bits 32]

; Define some constants
VIDEO_MEMORY equ 0xb8000
WHITE_ON_BLACK equ 0x0f

; prints a null - terminated string pointed to by EBX
print_string32:
	pusha
	mov edx, VIDEO_MEMORY + 80 * 2 ; Set edx to the start of vid mem.

.looe:
	mov al, [ebx] ; Store the char at EBX in AL
	mov ah, WHITE_ON_BLACK ; Store the attributes in AH
	cmp al, 0 ; Check if it's the NULL character (null terminating)
	je .done ; jump to done
	mov [edx], ax ; Store char and attributes at current
	; character cell.
	add ebx , 1 ; Increment EBX to the next char in string.
	add edx , 2 ; Move to next character cell in vid mem.
	jmp .looe

.done:
	popa
	ret ; Return from the function

; Prints hex at EAX
; print_hex32:
; 	pusha
; 	mov edx, hex32 + 7;
; 	;
; 	mov ebx, eax;
; 	and ebx, 0xf
; 	mov ebx, [hexes32 + ebx]
; 	mov [edx], bl
; 	sub edx, 1
; 	shr eax, 4
; 	;
; 	mov ebx, eax;
; 	and ebx, 0xf
; 	mov ebx, [hexes32 + ebx]
; 	mov [edx], bl
; 	sub edx, 1
; 	shr eax, 4
; 	;
; 	mov ebx, eax;
; 	and ebx, 0xf
; 	mov ebx, [hexes32 + ebx]
; 	mov [edx], bl
; 	sub edx, 1
; 	shr eax, 4
; 	;
; 	mov ebx, eax;
; 	and ebx, 0xf
; 	mov ebx, [hexes32 + ebx]
; 	mov [edx], bl
; 	sub edx, 1
; 	shr eax, 4
; 	;
; 	mov ebx, eax;
; 	and ebx, 0xf
; 	mov ebx, [hexes32 + ebx]
; 	mov [edx], bl
; 	sub edx, 1
; 	shr eax, 4
; 	;
; 	mov ebx, eax;
; 	and ebx, 0xf
; 	mov ebx, [hexes32 + ebx]
; 	mov [edx], bl
; 	sub edx, 1
; 	shr eax, 4
; 	;
; 	mov ebx, eax;
; 	and ebx, 0xf
; 	mov ebx, [hexes32 + ebx]
; 	mov [edx], bl
; 	sub edx, 1
; 	shr eax, 4
; 	;
; 	mov ebx, eax;
; 	and ebx, 0xf
; 	mov ebx, [hexes32 + ebx]
; 	mov [edx], bl
; 	sub edx, 1
; 	shr eax, 4
; 	; Print it
; 	mov ebx, prehex32
; 	call print_string32
; 	popa
; 	ret

hexes32:
	db "0123456789ABCDEF";
prehex32:
	db "0x";
hex32:
	db "00000000", 0