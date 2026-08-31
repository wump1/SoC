/*
 * GPIO blink demo (the M7 example, written now that GPIO actually exists
 * at M8 -- writing it earlier would have tested a peripheral address with
 * nothing behind it). Deliberately infinite: this is meant to run
 * forever on real hardware. tb_gpio_blink.sv verifies it by watching
 * gpio_out toggle for a bounded number of cycles rather than waiting for
 * a halt, since there is no halt to wait for.
 */
#define GPIO_ADDR ((volatile unsigned int *)0x20000004)

static void delay(volatile unsigned int n)
{
    while (n--) {
    }
}

void main(void)
{
    while (1) {
        *GPIO_ADDR = 1;
        delay(20);
        *GPIO_ADDR = 0;
        delay(20);
    }
}
