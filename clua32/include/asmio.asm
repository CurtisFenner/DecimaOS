;@ char, port_byte_in, int
_fun_port_byte_in:
; Short? For port
mov ebx, esp
add ebx, 4 ; reference first parameter
mov dx, [ebx]
mov eax, 0
in al, dx
ret

;@ char, port_word_in, int
_fun_port_word_in:
; Short? For port
mov ebx, esp
add ebx, 4 ; reference first parameter
mov dx, [ebx]
mov eax, 0
in ax, dx
ret