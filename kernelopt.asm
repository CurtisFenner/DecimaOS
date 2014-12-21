[org 0x9000] ; 
[bits 32] ; 
kernel :; 
call _fun_main; 
jmp $; 
_fun_console_printc: ; 
mov eax, esp; 
add eax, 16; 
push eax;  str
pop ebx; 
mov eax, [ebx]; 
push eax;  dereference
pop ebx; 
mov eax, [ebx]; 
push eax; 
push 0; 
_while_pre_condition_2: ; 
mov eax, esp; 
add eax, 24; 
push eax;  str
mov eax, esp; 
add eax, 4; 
push eax;  i
pop ebx; 
mov eax, [ebx]; 
push eax; 
pop ecx; 
pop ebx; 
mov eax, [ebx]; 
push eax; 
push ecx;  now rvalues
pop eax; 
pop ecx; 
imul eax, 1;  pointer math on char*
add eax, ecx; 
push eax;  dereference
pop ebx; 
mov eax, [ebx]; 
push eax; 
mov eax, 0; 
pop ebx; 
mov al, bl;  cast char -> int
push eax; 
push 0; 
pop ecx; 
pop eax; 
cmp eax, ecx;  > here and down
jg _positive_3; 
push dword 0; 
jmp _cmp_end_3; 
_positive_3: ; 
push dword 1; 
_cmp_end_3: ;  > here and up
pop eax; 
cmp eax, 0; 
je _while_end_2; 
mov eax, esp; 
add eax, 16; 
push eax;  x
mov eax, esp; 
add eax, 4; 
push eax;  i
pop ebx; 
mov eax, [ebx]; 
push eax; 
pop ecx; 
pop ebx; 
mov eax, [ebx]; 
push eax; 
push ecx;  now rvalues
pop ecx; 
pop eax; 
add eax, ecx; 
push eax;  int-type addition
mov eax, esp; 
add eax, 16; 
push eax;  y
mov ebx, esp; 
add ebx, 0; 
mov ecx, [ebx]; 
mov eax, [ecx]; 
mov [ebx], eax;  convert to rvalue
call _fun_console_index;  void console_index
add esp, 8;  (cleanup parameters)
push eax;  returned value
mov eax, esp; 
add eax, 0; 
push eax;  c
push 0;  addition
pop ecx; 
pop ebx; 
mov eax, [ebx]; 
push eax; 
push ecx;  now rvalues
pop eax; 
pop ecx; 
imul eax, 1;  pointer math on char*
add eax, ecx; 
push eax;  dereference
mov eax, esp; 
add eax, 32; 
push eax;  str
mov eax, esp; 
add eax, 12; 
push eax;  i
pop ebx; 
mov eax, [ebx]; 
push eax; 
pop ecx; 
pop ebx; 
mov eax, [ebx]; 
push eax; 
push ecx;  now rvalues
pop eax; 
pop ecx; 
imul eax, 1;  pointer math on char*
add eax, ecx; 
push eax;  dereference
pop ebx; 
mov eax, [ebx]; 
push eax; 
pop eax; 
pop ebx; 
mov [ebx], al;  assignment
mov eax, esp; 
add eax, 0; 
push eax;  c
push 1;  addition
pop ecx; 
pop ebx; 
mov eax, [ebx]; 
push eax; 
push ecx;  now rvalues
pop eax; 
pop ecx; 
imul eax, 1;  pointer math on char*
add eax, ecx; 
push eax;  dereference
mov eax, esp; 
add eax, 28; 
push eax;  style
pop ebx; 
mov eax, [ebx]; 
push eax; 
pop eax; 
pop ebx; 
mov [ebx], al;  assignment
mov eax, esp; 
add eax, 4; 
push eax;  i
mov eax, esp; 
add eax, 8; 
push eax;  i
push 1;  addition
pop ecx; 
pop ebx; 
mov eax, [ebx]; 
push eax; 
push ecx;  now rvalues
pop ecx; 
pop eax; 
add eax, ecx; 
push eax;  int-type addition
pop eax; 
pop ebx; 
mov [ebx], eax;  assignment
add esp, 4; 
jmp _while_pre_condition_2; 
_while_end_2: ;  }
add esp, 8; 
ret ; 
_fun_console_clear: ; 
push ` `; 
call _fun_console_fill;  void console_fill
add esp, 4;  (cleanup parameters)
ret ; 
_fun_console_fill: ; 
push 0x000b8000; 
push 0; 
_while_pre_condition_4: ; 
mov eax, esp; 
add eax, 0; 
push eax;  i
push 80; 
push 25; 
pop ecx; 
pop eax; 
imul eax, ecx; 
push eax; 
pop ecx; 
pop ebx; 
mov eax, [ebx]; 
push eax; 
pop eax; 
cmp eax, ecx;  < here and down
jl _positive_5; 
push dword 0; 
jmp _cmp_end_5; 
_positive_5: ; 
push dword 1; 
_cmp_end_5: ;  < here and up
pop eax; 
cmp eax, 0; 
je _while_end_4; 
mov eax, esp; 
add eax, 4; 
push eax;  screen
mov eax, esp; 
add eax, 4; 
push eax;  i
push 2; 
pop ecx; 
pop ebx; 
mov eax, [ebx]; 
push eax; 
pop eax; 
imul eax, ecx; 
push eax;  addition
pop ecx; 
pop ebx; 
mov eax, [ebx]; 
push eax; 
push ecx;  now rvalues
pop eax; 
pop ecx; 
imul eax, 1;  pointer math on char*
add eax, ecx; 
push eax;  dereference
mov eax, esp; 
add eax, 16; 
push eax;  w
pop ebx; 
mov eax, [ebx]; 
push eax; 
pop eax; 
pop ebx; 
mov [ebx], al;  assignment
mov eax, esp; 
add eax, 0; 
push eax;  i
mov eax, esp; 
add eax, 4; 
push eax;  i
push 1;  addition
pop ecx; 
pop ebx; 
mov eax, [ebx]; 
push eax; 
push ecx;  now rvalues
pop ecx; 
pop eax; 
add eax, ecx; 
push eax;  int-type addition
pop eax; 
pop ebx; 
mov [ebx], eax;  assignment
jmp _while_pre_condition_4; 
_while_end_4: ;  }
add esp, 8; 
ret ; 
_fun_console_index: ; 
push 0x000b8000; 
mov eax, esp; 
add eax, 12; 
push eax;  x
mov eax, esp; 
add eax, 12; 
push eax;  y
push 80; 
pop ecx; 
pop ebx; 
mov eax, [ebx]; 
push eax; 
pop eax; 
imul eax, ecx; 
push eax;  addition
pop ecx; 
pop ebx; 
mov eax, [ebx]; 
push eax; 
push ecx;  now rvalues
pop ecx; 
pop eax; 
add eax, ecx; 
push eax;  int-type addition
push 2; 
pop ecx; 
pop eax; 
imul eax, ecx; 
push eax;  addition
pop ecx; 
push ecx;  now rvalues
pop eax; 
pop ecx; 
imul eax, 1;  pointer math on char*
add eax, ecx; 
push eax; 
pop eax; 
ret ; 
ret ; 
_global___string_literal_1: ; 
db "The Decima C kernel has successfully started.", 0; 
_fun_main: ; 
call _fun_console_clear;  void console_clear
push _global___string_literal_1;  __string_literal_1
mov eax, esp; 
add eax, 0; 
push eax;  msg
push 0x0F; 
push 0; 
push 0; 
mov ebx, esp; 
add ebx, 12; 
mov ecx, [ebx]; 
mov eax, [ecx]; 
mov [ebx], eax;  convert to rvalue
call _fun_console_printc;  void console_printc
add esp, 16;  (cleanup parameters)
add esp, 4; 
ret ; 