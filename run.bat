
@echo off

set prompt=$$$G$S

lua optimize_folder.lua asm
lua optimize_folder.lua asm_compiled asm_optimized

cd asm_optimized
echo nasm main.asm
C:/nasm/nasm.exe   main.asm     -f bin -o ../bin/bootloader.bin
echo nasm kernel.asm
C:/nasm/nasm.exe   kernel.asm   -f bin -o ../bin/kernel.bin
echo nasm ten.asm
C:/nasm/nasm.exe   ten.asm      -f bin -o ../bin/ten.bin
cd ..

cd bin
echo Catting into os_image.bin
lua ../lcat.lua    bootloader.bin    kernel.bin    ten.bin       os_image.bin
cd ..

echo Qemu
qemu-system-x86_64w bin/os_image.bin

@echo on