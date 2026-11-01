cpu 386
org 0x100
 mov ah,0x52
 int 0x21
 mov ax,[es:bx-2]
 mov es,ax
nxt:
 mov ax,es
 call hex16
 mov dl,' '
 call putc
 mov ax,[es:1]
 call hex16
 mov dl,' '
 call putc
 mov ax,[es:3]
 call hex16
 mov dl,' '
 call putc
 mov cx,8
 xor si,si
nm: mov dl,[es:8+si]
 or dl,dl
 jnz ok
 mov dl,'.'
ok: call putc
 inc si
 loop nm
 mov dl,13
 call putc
 mov dl,10
 call putc
 mov al,[es:0]
 cmp al,'Z'
 je done
 mov ax,es
 add ax,[es:3]
 inc ax
 mov es,ax
 jmp nxt
done: mov ax,0x4C00
 int 0x21
putc: push ax
 mov ah,2
 int 0x21
 pop ax
 ret
hex16: push ax
 mov al,ah
 call hex8
 pop ax
hex8: push ax
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
