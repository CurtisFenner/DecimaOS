#include console.c





void main() {
	console_clear();
	char * msg = "The Decima C kernel has successfully started.";
	console_printc(msg, (char)0xF0, 0, 0);
}
