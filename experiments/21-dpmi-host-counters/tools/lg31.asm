bits 16
org 0x9000
 mov di,[bp+6]
 push ax
 push bx
 mov ax,[di+0x1c]
 mov bl,ah
 xor bh,bh
 and bx,0x1f
 shl bx,4
 and ax,0x0f
 add bx,ax
 inc byte [bx+0x9100]
 jnz .ok
 mov byte [bx+0x9100],0xff
.ok:
 pop bx
 pop ax
 jmp 0x3623
