#include <stdio.h>
#include <string.h>
#include "util.h"

#define SIGN_INDEX 0
#define LENGTH_INDEX 4
#define REPRESENTATION_INDEX 8
#define SIGN_REPRESENTATION_LENGTH sizeof(unsigned int)
#define LENGTH_REPRESENTATION_LENGTH sizeof(unsigned int)
#define MAGIC_PADDING 128

/* TODO implement this function in assembly, in the calc.asm file 
 * Additional *.asm files can be used, but must be in assembly */
extern void do_operation(void *a, void *b, char *operation)
	asm("do_operation");


static void print_hex_digit(unsigned char digit)
{
	if (digit <= 0x9) {
		putchar(digit + '0');
	} else {
		digit -= 10;
		putchar(digit + 'A');
	}
}

static void dump_byte(unsigned char number, int padding)
{
	unsigned char digit;

	/* print first digit */
	digit = number;
	/* clear lower half and align to right */
	digit = digit >> 4;
	/* print the nibble only if it is not 0 or the padding is active */
	if(digit != 0 || padding)
		print_hex_digit(digit);

	/* print second digit */
	digit = number;
	/* clear upper half */
	digit = digit << 4;
	/* align back to right */
	digit = digit >> 4;
	print_hex_digit(digit);
}

static void dump_number(unsigned char *mm)
{
	unsigned char *mm_ptr = (unsigned char *)(mm + REPRESENTATION_INDEX);
	unsigned int length = *((unsigned int *) (mm + LENGTH_INDEX));
	unsigned int i;

	for(i = 0; i < REPRESENTATION_INDEX; i++)
		dump_byte(mm[i], 1);

	for (i = 0; i < length; i++)
		dump_byte(mm_ptr[i], 1);

	putchar('\n');
}

static unsigned char hex_to_num(char hex_val)
{
	if('0' <= hex_val && hex_val <= '9')
		return hex_val - '0';

	wtf(!('A' <= hex_val && hex_val <= 'F'), "[hex_to_num] Wrong hex value\n");
	return hex_val - 'A' + 10;
}

static void allocate_vectors(char *a_str, char *b_str,
			     unsigned char **a_ptr, unsigned char **b_ptr)
{
	unsigned char *a, *b;
	unsigned int a_len, b_len;
	unsigned int max_str_len;
	unsigned int total_length;

	a_len = strlen(a_str);
	b_len = strlen(b_str);

	/* the sign itself gets counted separately */
	if (a_str[0] == '-')
		a_len--;
	if (b_str[0] == '-')
		b_len--;

	max_str_len = MAX(a_len, b_len);

	/* some numbers might have the MSB represented as a single hex digit
	 * inside the input */
	if (max_str_len % 2)
		max_str_len++;

	/* Although 2 hex digits can be represented on one byte,
	 * the result itself might be double the size of biggest operand
	 * Examples: mul operation */
	total_length = max_str_len * 2;
	total_length += SIGN_REPRESENTATION_LENGTH;
	total_length += LENGTH_REPRESENTATION_LENGTH;
	total_length += MAGIC_PADDING;
	a = calloc(1, total_length);
	wtf(a == NULL, "Could not allocate space to represent A");
	b = calloc(1, total_length);
	wtf(b == NULL, "Could not allocate space to represent B");

	*a_ptr = a;
	*b_ptr = b;
}

static void convert_one_to_native(char *s_str, void *s)
{
	unsigned int s_len;
	unsigned int s_bytes_len;
	int i, j;

	s_len = strlen(s_str);

	if (s_str[0] == '-') {
		/* the sign itself gets counted separately */
		s_len--;

		/* number[SIGN_INDEX] = zeros if number is positive
	 	 * number[SIGN_INDEX] = all ones if number is negative */	
		memset(s + SIGN_INDEX, 0xFF, SIGN_REPRESENTATION_LENGTH);

		/* ignore the sign */
		s_str++;
	}
	else {
		memset(s + SIGN_INDEX, 0x00, SIGN_REPRESENTATION_LENGTH);
	}
		

	/* The string itself is double the size
	 * because there are 2 hex digits per byte */
	/* Added and extra byte
	 * in case the MSB value was represented by a single hex digit */
	s_bytes_len = s_len / 2 + s_len % 2;
	memcpy(s + LENGTH_INDEX, &s_bytes_len, LENGTH_REPRESENTATION_LENGTH);

	for(i = 0, j = s_len - 1; i < s_bytes_len; i++, j -= 2) {
		unsigned char digit = 0;

		// get first hex digit (if it exists)
		if(j - 1 >= 0)
			digit = hex_to_num(s_str[j - 1]);

		// get second hex digit
		digit <<= 4;
		digit |= hex_to_num(s_str[j]);

		// include the digit in the native representation
		memcpy(s + REPRESENTATION_INDEX + i, &digit, sizeof(unsigned char));
	}
}

static void convert_to_native(char *a_str, char *b_str, void *a, void *b) {
	convert_one_to_native(a_str, a);
	convert_one_to_native(b_str, b);
}

static void print_number(unsigned char *number)
{
	unsigned int sign = *((unsigned int *) (number + SIGN_INDEX));
	unsigned int length = *((unsigned int *) (number + 
						    LENGTH_REPRESENTATION_LENGTH));
	unsigned char *repr = number + REPRESENTATION_INDEX;

	int i;

	wtf((sign != 0x00000000 && sign != 0xFFFFFFFF), 
		"Wrong sign representation of number\n");
	wtf(length == 0,
		"Length of a number should always be greater than 0\n");

	// print the sign if necessary
	if(sign == 0xFFFFFFFF)
		putchar('-');

	// print the most significant byte
	// (and remove the most significant nibble if it is 0)
	int last = ((int) length) - 1;
	dump_byte(repr[last], 0);

	// print the other bytes
	for(i = ((int) length) - 2; i >= 0; i--)
		dump_byte(repr[i], 1);
	printf("\n");
}

int main(int argc, char *argv[])
{
	char *a_str, *b_str;
	unsigned char *a, *b;
	char *operation;

	wtf(argc < 4, "Not enough paramateres\n"
		      "Usage:\n"
		      "\t%s $A op $B\n"
		      "Example:\n"
		      "\t%s FF34AAAAA3341 + 000012342341FFF",
		      argv[0], argv[0]);

	/* input thingie */
	/* A=argv[1] op=argv[2] B=argv[3] */
	a_str = argv[1];
	b_str = argv[3];
	operation = argv[2];

	allocate_vectors(a_str, b_str, &a, &b);
	/* number[SIGN_INDEX] = zeros if number is positive
	 * number[SIGN_INDEX] = all ones if number is negative
	 * number[LENGTH_INDEX] = actual length of number 
	 * - these things are already set in the A and B pointers 
	 * - length is represented in bytes 
	 * - the actual space allocated for A and B is bigger than the actual
	 * size. Mainly because one of them is used to store the result, which
	 * might be double in size for operations such as "mul" */
	convert_to_native(a_str, b_str, a, b);

	/* memory dump of native representation of numbers a and b */
	// dump_number(a);
	// dump_number(b);

	/* store result in A */
	/* be sure to store correct length and remove any padding zeros */
	do_operation(a, b, operation);
	
	/* memory dump of native representation of number */
	// dump_number(a);

	/* print the number in the format the input was received */
	/* This function should receive a number with NO padding zeros */
	print_number(a);

	free(a);
	free(b);

	return 0;
}
