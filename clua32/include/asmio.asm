;@ char, port_byte_in, int
_port_byte_in:
; Short? For port
mov ebx, esp

in al, dx
ret