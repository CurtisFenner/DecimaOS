// Characters are 8x19

// Screen is 640 x 480
// Screen is 80 x 25 chars

// Style: background:foreground

// Darks: 0 black, 1 blue, 2 green, 3 teal, 4 red, 5 magenta, 6 orange, 7 light grey,
// Lights: 8 dark grey, 9 blue, A green, B teal, C red, D magenta, E yellow, F white
// 8 - F approximately add (87, 87, 87) in terms of 24bit RGB to 0 - 7.
// Exception: E and 6

// Memory at 0x000b8000

// Stupid integer mod (undefined for negative b) always positive
int mod(int a, int b) {
	if (a > b) {
		return mod(a - b, b);
	}
	if (a < 0) {
		return mod(a + b, b);
	}
	return a;
}

// Stupid integer division
int div(int a, int b) {
	if (a < 0) {
		return 0-div(-a, b);
	}
	if (b < 0) {
		return 0-div(a, -b);
	}
	if (a < b) {
		return 0;
	}
	int i = 0;
	while (a > b * i) {
		i = i + 1;
	}
	return i;
}

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

// static
void console_char(char c, char style, int x, int y) {
	char * c = console_index(x, y);
	c[0] = c;
	c[1] = style;
}

void console_printc(char * str, char style, int x, int y) {
	char k = *str;
	int i = 0;
	while ( (int)str[i] > 0) {
		console_char(str[i], style, x + i, y);
		i = i + 1;
	}
}



// Prints integer num
// Returns length (in characters printed) of num
int console_printi(int num, char style, int x, int y) {
	// x, y are left.
	if (num < 0) {
		console_char('-', style, x, y);
		return 1;// + console_printi(0-num, style, x + 1, y);
	} else {
		if (num == 0) {
			console_char('0', style, x, y);
			return 1;
		}
		console_char((char)(48 /*'0'*/ + mod(num, 10)), style, x, y);
		return 1;// + console_printi(div(num, 10), style, x, y);
	}
}