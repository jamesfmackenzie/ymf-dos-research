; DPMIT.COM - minimal 16-bit DPMI client (INT 2F/1687). Runs the IN battery in PM and
; prints CS.RPL / flags. Only INT 21h AH=2 (no pointers) is used from PM.
cpu 386
bits 16
org 0x100
start:
 mov al,[0x82]
 mov [part],al
 mov bx,0x1000
 mov ah,0x4A
 int 0x21
 mov ax,0x1687
 int 0x2F
 test ax,ax
 jz .have
 mov dx,s_nodpmi
 call puts
 mov ax,0x4C01
 int 0x21
.have:
 mov [ent],di
 mov [ent+2],es
 mov [fl],bx
 mov [cpux],cx
 mov [ver],dx
 mov [need],si
 mov dx,s_hdr
 call puts
 mov ax,[fl]
 call hex16
 mov dx,s_cpu
 call puts
 mov ax,[cpux]
 call hex16
 mov dx,s_ver
 call puts
 mov ax,[ver]
 call hex16
 mov dx,s_need
 call puts
 mov ax,[need]
 call hex16
 mov dx,s_ent
 call puts
 mov ax,[ent+2]
 call hex16
 mov dl,':'
 call putc
 mov ax,[ent]
 call hex16
 call crlf
 cmp byte [part],'Q'
 jne .noq
 call qpiinit
.noq:
 ; V86 battery
 mov dx,s_v86
 call puts
 call battery
 mov bx,[need]
 or bx,bx
 jz .noalloc
 mov ah,0x48
 int 0x21
 jc .fail1
 mov es,ax
.noalloc:
 xor ax,ax
 call far [ent]
 jc .fail2
 ; --- now in protected mode
 mov dx,s_pm
 call puts
 mov dx,s_cpl
 call puts
 mov ax,cs
 and ax,3
 call hex16
 mov dx,s_sel
 call puts
 mov ax,cs
 call hex16
 call crlf
 mov dx,s_bat
 call puts
 call battery
 mov dx,s_cb
 call puts
 mov ax,[cbcnt]
 call hex16
 mov dx,s_ok
 call puts
 mov ax,0x4C00
 int 0x21
.fail1:
 mov dl,'1'
 call putc
 jmp .fail
.fail2:
 mov dl,'2'
 call putc
 mov dl,al
 call hexb
.fail:
 mov dx,s_fail
 call puts
 mov ax,0x4C01
 int 0x21

battery:
 mov dx,2
 in al,dx
 call hexb
 call sp_
 mov dx,4
 in al,dx
 call hexb
 call sp_
 mov dx,0xED
 in al,dx
 call hexb
 call sp_
 mov dx,0x83
 in al,dx
 call hexb
 call crlf
 ret
sp_: mov dl,' '
putc: push ax
 push dx
 mov ah,2
 int 0x21
 pop dx
 pop ax
 ret
puts: push ax
 push dx
 push si
 mov si,dx
.l: mov dl,[si]
 cmp dl,'$'
 je .e
 mov ah,2
 int 0x21
 inc si
 jmp .l
.e: pop si
 pop dx
 pop ax
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
 call hexn
 pop ax
hexn: and al,0xF
 add al,'0'
 cmp al,'9'
 jbe .pp
 add al,7
.pp: mov dl,al
 jmp putc
s_nodpmi db 'no DPMI host (1687)',13,10,'$'
s_hdr db 'DPMI host: flags=$'
s_cpu db ' cpu=$'
s_ver db ' ver=$'
s_need db ' paras=$'
s_ent db ' entry=$'
s_v86 db 'V86 IN 02/04/ED/83: $'
s_pm db 'PM client:',13,10,'$'
s_cpl db ' CS.RPL=$'
s_sel db ' CS=$'
s_bat db ' IN 02/04/ED/83: $'
s_ok db 'PM ran to completion',13,10,'$'
s_fail db 'switch failed',13,10,'$'
qpiinit:
 push es
 xor di,di
 mov es,di
 mov ax,0x1684
 mov bx,0x4354
 int 0x2F
 cmp al,0
 jne .no
 mov [qpi],di
 mov [qpi+2],es
 push cs
 pop es
 mov di,cb
 mov ax,0x1A07
 call far [qpi]
 mov dx,2
 mov ax,0x1A09
 call far [qpi]
.no:
 pop es
 ret
cb:
 pushad
 push ds
 push cs
 pop ds
 mov bp,sp
 inc word [cbcnt]
 test byte [bp+2+24],4
 jnz .done
 mov dword [bp+2+28],0xA5A5A5A5
.done:
 pop ds
 popad
 clc
 retf
s_cb db ' QPI cb count=$'
part db 0
cbcnt dw 0
qpi dd 0
ent dd 0
fl dw 0
cpux dw 0
ver dw 0
need dw 0
