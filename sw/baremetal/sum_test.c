/*
 * First bare-metal C program: proves the GNU C compiler's codegen for
 * -march=rv32i -mabi=ilp32 runs correctly on this core -- a real function
 * call/return through the stack (not inlined at -O0), a loop, and a
 * write to a statically-allocated global -- checked by the testbench
 * reading memory directly, the same way tb_loadstore.sv does.
 *
 * No division or multiplication: those can pull in libgcc helper calls
 * (__divsi3 etc.), and this build is -nostdlib with nothing to link them
 * against.
 */

volatile unsigned int g_result;
volatile unsigned int g_done;

static int sum_to_n(int n)
{
    int total = 0;
    for (int i = 1; i <= n; i++) {
        total += i;
    }
    return total;
}

void main(void)
{
    g_result = (unsigned int)sum_to_n(10);
    g_done = 1;
}
