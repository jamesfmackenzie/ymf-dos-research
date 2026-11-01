/* XT.C - DOS extender I/O trap probe. Build: wcl386 -bt=dos -l=<sys> xt.c  (sys = dos4g|pmodew|dos32a)
   Reports CPL, IOPL and DMA-port behaviour to XT.TXT (appended) and stdout. */
#include <stdio.h>
#include <stdlib.h>
extern unsigned short get_cs(void);
#pragma aux get_cs = "mov ax,cs" value [ax];
extern unsigned long get_eflags(void);
#pragma aux get_eflags = "pushfd" "pop eax" value [eax];
extern void outb(unsigned short p, unsigned char v);
#pragma aux outb = "out dx,al" parm [dx] [al];
extern unsigned char inb(unsigned short p);
#pragma aux inb = "in al,dx" parm [dx] value [al];

int main(int argc, char **argv)
{
    unsigned short cs = get_cs();
    unsigned long fl = get_eflags();
    unsigned char a0, a1, st0, st1, pg;
    FILE *f = fopen("XT.TXT", "a");
    const char *tag = argc > 1 ? argv[1] : "?";

    /* ch1 base address 0x3412 via flip-flop, read back (Dsdma-hooked channel reads FF) */
    outb(0x0C, 0);          /* clear flip-flop */
    outb(0x02, 0x12);
    outb(0x02, 0x34);
    outb(0x0C, 0);
    a0 = inb(0x02);
    a1 = inb(0x02);
    st0 = inb(0x08);        /* status */
    outb(0x0A, 0x05);       /* mask ch1 */
    outb(0x0B, 0x45);       /* mode ch1 single read */
    st1 = inb(0x08);
    pg = inb(0x83);
    outb(0x0A, 0x01);       /* unmask ch1 off */
    outb(0x0A, 0x05);       /* leave masked */

    fprintf(f ? f : stdout, "%s: CS=%04X CPL=%u IOPL=%u EFL=%08lX ch1addr_rb=%02X%02X st=%02X/%02X pg83=%02X\n",
            tag, cs, cs & 3, (unsigned)((fl >> 12) & 3), fl, a1, a0, st0, st1, pg);
    printf("%s: CS=%04X CPL=%u IOPL=%u ch1addr_rb=%02X%02X st=%02X/%02X pg83=%02X\n",
           tag, cs, cs & 3, (unsigned)((fl >> 12) & 3), a1, a0, st0, st1, pg);
    if (f) fclose(f);
    return 0;
}
