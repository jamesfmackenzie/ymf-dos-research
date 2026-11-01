; QC.COM - resident QPI callback counter. "QC I" installs (traps ports 02,08,0C,0A,0B,83 pass-through
; via QPI 1A04 and logs port+CL); "QC R" prints count and log via INT 6Bh. Needs QPIEMU loaded.
cpu 386
bits 16
org 0x100
MAXREC equ 48
start:
 mov al,[0x82]
 cmp al,'R'
 je report
 mov ax,1684h
 mov bx,4354h
 xor di,di
 mov es,di
 int 2Fh
 cmp al,0
 jne noqpi
 mov [qpi],di
 mov [qpi+2],es
 mov ax,1A07h
 push cs
 pop es
 mov di,cb
 call far [qpi]
 mov si,ports
.l: lodsw
 or ax,ax
 jz .d
 mov dx,ax
 push si
 mov ax,1A09h
 call far [qpi]
 pop si
 jmp .l
.d:
 mov ax,256Bh
 mov dx,i6b
 int 21h
 mov dx,s_inst
 mov ah,9
 int 21h
 mov dx,resend
 add dx,15
 shr dx,4
 mov ax,3100h
 int 21h
noqpi:
 mov dx,s_noqpi
 mov ah,9
 int 21h
 mov ax,4C01h
 int 21h

i6b: ; returns ES:BX = count, CX=records base
 push cs
 pop es
 mov bx,count
 iret

cb:
 pushad
 push ds
 push cs
 pop ds
 mov bp,sp
 mov bx,[count]
 cmp bx,MAXREC
 jae .nolog
 shl bx,2
 mov ax,[bp+2+20]
 mov [log+bx],ax
 mov ax,[bp+2+24]
 mov [log+bx+2],ax
.nolog:
 inc word [count]
 movzx ecx,word [bp+2+24]
 mov dx,[bp+2+20]
 mov ebx,[bp+2+28]
 mov ax,1A04h
 call far [qpi]
 test byte [bp+2+24],4
 jnz .done
 mov [bp+2+28],ebx
.done:
 pop ds
 popad
 clc
 retf

report:
 int 6Bh
 mov ax,[es:bx]
 push es
 pop ds
 mov [n],ax
 mov dx,s_cnt
 mov ah,9
 int 21h
 mov ax,[n]
 call hex16
 call crlf
 mov cx,[n]
 cmp cx,MAXREC
 jbe .ok
 mov cx,MAXREC
.ok: xor si,si
.r: jcxz .e
 push cx
 mov ax,[log+si]
 call hex16
 mov dl,'/'
 call putc
 mov ax,[log+si+2]
 call hex16
 mov dl,' '
 call putc
 pop cx
 add si,4
 dec cx
 jmp .r
.e: call crlf
 mov ax,4C00h
 int 21h
putc: mov ah,2
 int 21h
 ret
crlf: mov dl,13
 call putc
 mov dl,10
 jmp putc
hex16: push ax
 mov al,ah
 call hexb
 pop ax
hexb: push ax
 shr al,4
 call nib
 pop ax
nib: and al,15
 add al,'0'
 cmp al,'9'
 jbe .p
 add al,7
.p: mov dl,al
 jmp putc

qpi dd 0
ports dw 2,8,0Ch,0Ah,0Bh,83h,0
s_inst db 'QC installed',13,10,'$'
s_noqpi db 'QC: no QPI',13,10,'$'
s_cnt db 'QC count=$'
n dw 0
count dw 0
log times MAXREC*4 db 0
resend:
