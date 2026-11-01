cpu 386
org 0x100
%macro MARK 0
 mov ax,0xBEEF
 int 0x2F
%endmacro
 push ds
 pop es
 MARK            ; m0: start
 in al,0x02      ; ch1 address  (hooked)
 MARK            ; m1
 in al,0x04      ; ch2 address  (not hooked)
 MARK            ; m2
 mov dx,2
 mov cx,2
 mov di,buf
 rep insb        ; ch1, 2 bytes
 MARK            ; m3
 in al,0x83      ; ch1 page
 MARK            ; m4
 in al,0x81      ; ch2 page
 MARK            ; m5
 in al,0x21      ; PIC1 mask
 MARK            ; m6
 in al,0xC4      ; ch5 address
 MARK            ; m7
 in al,0x92      ; A20/fast gate
 MARK            ; m8
 in al,0x60      ; keyboard data
 MARK            ; m9
 mov ax,0x4C00
 int 0x21
buf: db 0,0
