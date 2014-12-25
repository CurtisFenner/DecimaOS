// Characters are 8x19
// Screen is 640 x 480
// Screen is 80 x 25 chars

#include <asmio>

void console_fill(char w) {
	char * screen = (char *) 0x000b8000;
	int i = 0;
	while (i < 80 * 25) {
		*(screen + i * 2) = w;
		i = i + 1;
	}
}

void console_clear() {
	console_fill(' ');
}

char * console_index(int x, int y) {
	return (char *) 0x000b8000 + (x + y * 80) * 2;
}

void console_printc(char * str, char style, int x, int y) {
	char k = *str;
	int i = 0;
	while ( (int)str[i] > 0) {
		char * c = console_index(x + i, y);
		c[0] = str[i];
		c[1] = style;
		i = i + 1;
	}
}

// Darks: 0 black, 1 blue, 2 green, 3 teal, 4 red, 5 magenta, 6 orange, 7 light grey,
// Lights: 8 dark grey, 9 blue, A green, B teal, C red, D magenta, E yellow, F white
// 8 - F approximately add (87, 87, 87) in terms of 24bit RGB to 0 - 7.
// Exception: E and 6

void main() {
	console_clear();
	char * msg = "The Decima C kernel has successfully started.";
	console_printc(msg, (char)0x0F, 0, 0);
}
