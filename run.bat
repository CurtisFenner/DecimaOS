
@echo off

set prompt=$$$G$S

echo "              Optimizing assembly files in /asm --> /asm_optimized"
lua optimize_folder.lua asm

echo "              Optimizing assembly files in /asm_compiled --> /asm_optimized"
lua optimize_folder.lua asm_compiled asm_optimized


cd asm_optimized
echo "              Compiling main.asm"
C:/nasm/nasm.exe   main.asm     -f bin -o ../bin/bootloader.bin
echo "              Compiling kernel.asm"
C:/nasm/nasm.exe   kernel.asm   -f bin -o ../bin/kernel.bin
echo "              Compiling ten.asm"
C:/nasm/nasm.exe   ten.asm      -f bin -o ../bin/ten.bin
cd ..

cd bin
echo "              catting results main.asm"
lua ../lcat.lua    bootloader.bin    kernel.bin    ten.bin       os_image.bin
cd ..

echo "              running os_image.bin"
qemu-system-x86_64w bin/os_image.bin

@echo on