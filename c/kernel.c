#include console.c
#include <asmio>



int isPrime(int n) {
	int d = 2;
	while (d < n) {
		if (mod(n, d) == 0) {
			return 0;
		}
		d++;
	}
	return 1;
}



void main() {
	console_clear();
	char * msg = "The Decima C kernel has successfully started.";
	console_printc(msg, (char)0xF0, 0, 0);
	console_printi(-148, (char)0xF0, 0, 4);
}
