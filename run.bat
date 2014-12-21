C:/nasm/nasm.exe main.asm -f bin -o bin/bootloader.bin
:: C:/nasm/nasm.exe kernel.c.asm -f bin -o bin/kernel.bin
C:/nasm/nasm.exe kernelopt.asm -f bin -o bin/kernel.bin
C:/nasm/nasm.exe ten.asm -f bin -o bin/ten.bin
cat bin/bootloader.bin bin/kernel.bin > bin/osimage.bin
cat bin/osimage.bin bin/ten.bin > bin/osimagepad.bin
qemu-system-x86_64w bin/osimagepad.bin