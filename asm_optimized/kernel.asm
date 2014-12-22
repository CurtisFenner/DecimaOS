[org 0x9000] 
[bits 32] 
kernel: 
call _fun_main 
jmp $ 
_fun_console_printc: 
mov eax, esp
add eax, 16
mov ebx, eax; optimize push pop
mov eax, [ebx]
mov ebx, eax; optimize push pop
mov eax, [ebx]
push eax
push 0
_while_pre_condition_2: 
mov eax, esp
add eax, 24
push eax;  str
mov eax, esp
add eax, 4
mov ebx, eax; optimize push pop
mov eax, [ebx]
pop ebx
mov ecx, eax; optimize push pop
mov eax, ecx; optimize clobbered by mov
mov ecx, [ebx]; optimize push pop
add eax, ecx
mov ebx, eax; optimize push pop
mov eax, 0; optimize clobbered by mov
mov ebx, [ebx]; optimize push pop
mov al, bl;  cast char -> int
mov ecx, 0; optimize push pop
cmp eax, ecx ;  > here and down
jg _positive_3 
push dword 0
jmp _cmp_end_3 
_positive_3: 
push dword 1
_cmp_end_3: ;  > here and up
pop eax
cmp eax, 0 
je _while_end_2 
mov eax, esp
add eax, 16
push eax;  x
mov eax, esp
add eax, 4
mov ebx, eax; optimize push pop
mov eax, [ebx]
pop ebx
mov ecx, eax; optimize push pop
mov eax, [ebx]
add eax, ecx
push eax;  int-type addition
mov eax, esp
add eax, 16
push eax;  y
mov ebx, esp
mov ecx, [ebx]
mov eax, [ecx]
mov [ebx], eax;  convert to rvalue
call _fun_console_index ;  void console_index
add esp, 8;  (cleanup parameters)
push eax;  returned value
mov eax, esp
mov ebx, eax; optimize push pop
mov ecx, 0; optimize push pop
mov eax, ecx; optimize clobbered by mov
mov ecx, [ebx]; optimize push pop
add eax, ecx
push eax;  dereference
mov eax, esp
add eax, 32
push eax;  str
mov eax, esp
add eax, 12
mov ebx, eax; optimize push pop
mov eax, [ebx]
pop ebx
mov ecx, eax; optimize push pop
mov eax, ecx; optimize clobbered by mov
mov ecx, [ebx]; optimize push pop
add eax, ecx
mov ebx, eax; optimize push pop
mov eax, [ebx]
pop ebx
mov [ebx], al;  assignment
mov eax, esp
mov ebx, eax; optimize push pop
mov ecx, 1; optimize push pop
mov eax, ecx; optimize clobbered by mov
mov ecx, [ebx]; optimize push pop
add eax, ecx
push eax;  dereference
mov eax, esp
add eax, 28
mov ebx, eax; optimize push pop
mov eax, [ebx]
pop ebx
mov [ebx], al;  assignment
mov eax, esp
add eax, 4
push eax;  i
mov eax, esp
add eax, 8
mov ebx, eax; optimize push pop
mov eax, [ebx]
add eax, 1; optimize literal add inline
pop ebx
mov [ebx], eax;  assignment
mov ecx, 1; optimize literal add inline
add esp, 4
jmp _while_pre_condition_2 
_while_end_2: ;  }
add esp, 8
ret 
_fun_console_clear: 
push ` `
call _fun_console_fill ;  void console_fill
add esp, 4;  (cleanup parameters)
ret 
_fun_console_fill: 
push 0x000b8000
push 0
_while_pre_condition_4: 
mov eax, esp
push eax;  i
mov eax, 80; optimize push pop
imul eax, 25; optimize literal imul inline
pop ebx
mov ecx, eax; optimize clobber mov
mov eax, [ebx]
cmp eax, ecx ;  < here and down
jl _positive_5 
push dword 0
jmp _cmp_end_5 
_positive_5: 
push dword 1
_cmp_end_5: ;  < here and up
pop eax
cmp eax, 0 
je _while_end_4 
mov eax, esp
add eax, 4
push eax;  screen
mov eax, esp
add eax, 4
mov ebx, eax; optimize push pop
mov eax, [ebx]
imul eax, 2; optimize literal imul inline
pop ebx
mov ecx, eax; optimize clobber mov
mov eax, ecx; optimize clobbered by mov
mov ecx, [ebx]; optimize push pop
add eax, ecx
push eax;  dereference
mov eax, esp
add eax, 16
mov ebx, eax; optimize push pop
mov eax, [ebx]
pop ebx
mov [ebx], al;  assignment
mov eax, esp
push eax;  i
mov eax, esp
add eax, 4
mov ebx, eax; optimize push pop
mov eax, [ebx]
add eax, 1; optimize literal add inline
pop ebx
mov [ebx], eax;  assignment
mov ecx, 1; optimize literal add inline
jmp _while_pre_condition_4 
_while_end_4: ;  }
add esp, 8
ret 
_fun_console_index: 
push 0x000b8000
mov eax, esp
add eax, 12
push eax;  x
mov eax, esp
add eax, 12
mov ebx, eax; optimize push pop
mov eax, [ebx]
imul eax, 80; optimize literal imul inline
pop ebx
mov ecx, eax; optimize clobber mov
mov eax, [ebx]
add eax, ecx
imul eax, 2; optimize literal imul inline
mov ecx, eax; optimize clobber mov
mov eax, ecx; optimize push pop
pop ecx
add eax, ecx
ret ; optimize double return
_global___string_literal_1: 
db "The Decima C kernel has successfully started.", 0 
_fun_main: 
call _fun_console_clear ;  void console_clear
push _global___string_literal_1;  __string_literal_1
mov eax, esp
push eax;  msg
push 0x0F
push 0
push 0
mov ebx, esp
add ebx, 12
mov ecx, [ebx]
mov eax, [ecx]
mov [ebx], eax;  convert to rvalue
call _fun_console_printc ;  void console_printc
add esp, 16 + 4; optimize add two literals
ret 
