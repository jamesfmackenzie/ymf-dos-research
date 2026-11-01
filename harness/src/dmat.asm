; DMAT.COM - probe 8237 / page-register behaviour from V86. Prints one line per test.
cpu 386
org 0x100
start:
 ; T1: address/count write-then-readback, channels 0-3
 xor bx,bx            ; BX = channel
t1:
 mov dx,msgA
 call puts
 mov al,bl
 call hexb
 mov dx,msgB
 call puts
 mov dx,bx
 add dx,dx
 out 0x0C,al
 mov ax,0x1234
 add ah,bl
 out dx,al
 mov al,ah
 out dx,al
 inc dx
 mov ax,0x00FF
 add al,bl
 out dx,al
 mov al,ah
 out dx,al
 out 0x0C,al
 dec dx
 in al,dx
 mov cl,al
 in al,dx
 mov ch,al
 push cx
 out 0x0C,al
 inc dx
 in al,dx
 mov cl,al
 in al,dx
 mov ch,al
 pop ax
 push cx
 call hex16
 mov dl,' '
 call putc
 pop ax
 call hex16
 call crlf
 inc bx
 cmp bx,4
 jb t1
 ; T2: page registers
 mov dx,msgP
 call puts
 mov si,pagelist
t2: lodsb
 or al,al
 jz t2d
 mov dl,al
 xor dh,dh
 mov al,0x5A
 out dx,al
 in al,dx
 push ax
 mov al,dl
 call hexb
 mov dl,'='
 call putc
 pop ax
 call hexb
 mov dl,' '
 call putc
 jmp t2
t2d: call crlf
 ; T3: status/temp/command read
 mov dx,msgS
 call puts
 in al,0x08
 call hexb
 mov dl,' '
 call putc
 in al,0x0D
 call hexb
 mov dl,' '
 call putc
 in al,0x0F
 call hexb
 call crlf
 ; T4: 16-bit controller ch5/ch6 (ports C4,C6) 
 mov dx,msg16
 call puts
 out 0xD8,al
 mov dx,0xC4
 mov al,0x78
 out dx,al
 mov al,0x56
 out dx,al
 out 0xD8,al
 in al,dx
 mov cl,al
 in al,dx
 mov ch,al
 mov ax,cx
 call hex16
 call crlf
 ; T5: REP OUTSB / INSB on ch1 address (port 02)
 mov dx,msgR
 call puts
 out 0x0C,al
 mov dx,2
 mov si,buf
 mov cx,2
 rep outsb
 out 0x0C,al
 mov di,buf2
 mov cx,2
 push ds
 pop es
 rep insb
 mov al,[buf2]
 call hexb
 mov al,[buf2+1]
 call hexb
 call crlf
 mov ax,0x4C00
 int 0x21
putc: push ax
 mov ah,2
 int 0x21
 pop ax
 ret
puts: push ax
 mov ah,9
 int 0x21
 pop ax
 ret
crlf: push dx
 mov dl,13
 call putc
 mov dl,10
 call putc
 pop dx
 ret
hex16: push ax
 mov al,ah
 call hexb
 pop ax
hexb: push ax
 shr al,4
 call hexn
 pop ax
hexn: and al,0xF
 add al,'0'
 cmp al,'9'
 jbe pp
 add al,7
pp: push dx
 mov dl,al
 call putc
 pop dx
 ret
msgA: db 'T1 ch$'
msgB: db ' A/C=$'
msgP: db 'T2 page 83/81/82/87/89/8A/8B: $'
msgS: db 'T3 status08/temp0D/0F: $'
msg16: db 'T4 ch5 addr C4 (7856 expected): $'
msgR: db 'T5 rep outsb 34 12 then rep insb: $'
pagelist: db 0x83,0x81,0x82,0x87,0x89,0x8A,0x8B,0
buf: db 0x34,0x12
buf2: db 0,0
