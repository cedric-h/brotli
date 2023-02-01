extern double log2(double);

#define HUGE_VAL ((union { double d; uint64_t u; }) { .u = 0b0111111111110000000000000000000000000000000000000000000000000000 }).d
