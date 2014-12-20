C:/nasm/nasm.exe main.asm -f bin -o bootloader.bin
C:/nasm/nasm.exe kernel.c.asm -f bin -o kernel.bin
C:/nasm/nasm.exe ten.asm -f bin -o ten.bin
cat bootloader.bin kernel.bin > osimage.bin
cat osimage.bin ten.bin > osimagepad.bin
qemu-system-x86_64w osimagepad.bin