;@ char, port_byte_in, int
_fun_port_byte_in:
; Short? For port
mov ebx, esp
add ebx, 4 ; reference first parameter
mov dx, [ebx]
in al, dx
ret