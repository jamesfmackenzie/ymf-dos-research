; PMT.COM - VCPI protected-mode client I/O trap test (Finding 19).
; usage: PMT V  = plain (Jemm only) ; PMT Q = also install a QPI callback trapping port 02
; The same IN battery is run from V86 (before), from the VCPI PM client (CPL0), and V86 (after).
cpu 386
bits 16
org 0x100

CSR0 equ 0x20
DSR0 equ 0x28
FLATSEL equ 0x30
TRSEL equ 0x38

start:
 mov al,[0x82]
 mov [part],al
 mov bx,0x1000
 mov ah,0x4A
 int 0x21
 mov ax,0xDE00
 int 0x67
 mov [de00],ax
 test ah,ah
 jz .vok
 mov dx,s_novcpi
 call puts
 mov ax,[de00]
 call hex16
 call crlf
 mov ax,0x4C01
 int 0x21
.vok:
 cmp byte [part],'Q'
 jne .noq
 call qpiinit
.noq:
 ; page tables
 mov bx,0x400
 mov ah,0x48
 int 0x21
 jnc .alok
 mov ax,0x4C02
 int 0x21
.alok:
 movzx eax,ax
 shl eax,4
 add eax,4095
 and eax,0xFFFFF000
 mov [m_cr3],eax
 mov edi,eax
 add edi,0x1000
 shr eax,4
 mov es,ax
 push edi
 xor edi,edi
 mov ecx,0x800
 xor eax,eax
 a32 rep stosd
 pop edi
 or di,7
 mov [es:0],edi
 mov ax,es
 add ax,0x100
 mov [ptseg],ax
 ; descriptors
 xor eax,eax
 mov ax,cs
 shl eax,4
 mov [pmcs+2],ax
 mov [pmds+2],ax
 mov ecx,eax
 shr eax,16
 mov [pmcs+4],al
 mov [pmds+4],al
 add [gdtbase],ecx
 add [idtbase],ecx
 add [m_gdtr],ecx
 add [m_idtr],ecx
 lea eax,[ecx+taskseg]
 mov [pmtr+2],ax
 shr eax,16
 mov [pmtr+4],al
 ; tss: esp0
 movzx eax,sp
 mov [taskseg+4],eax
 mov word [taskseg+8],DSR0
 mov word [taskseg+0x66],0x68
 ; idt
 mov di,idt
 mov cx,256
.gl:
 mov ax,defint
 cmp cx,256-13
 je .gp
 cmp cx,256-14
 jne .gs
.gp:
 mov ax,gph
.gs:
 mov [di],ax
 mov word [di+2],CSR0
 mov word [di+4],0xEE00
 mov word [di+6],0
 add di,8
 loop .gl
 ; DE01
 mov es,[ptseg]
 xor di,di
 mov si,restab
 mov ax,0xDE01
 int 0x67
 test ah,ah
 jz .d1ok
 mov dx,s_de01
 call puts
 mov ax,0x4C03
 int 0x21
.d1ok:
 mov [vcpiofs],ebx
 mov ax,cs
 mov es,ax
 ; V86 battery before
 mov dx,s_v86a
 call puts
 mov di,r_v1
 call battery
 call printbat
 ; switch
 cli
 mov [segcs],cs
 mov [segds],ds
 movzx eax,ax
 xor eax,eax
 mov ax,ds
 shl eax,4
 lea esi,[eax+msw]
 movzx ebx,sp
 mov ax,0xDE0C
 int 0x67
pmentry:
 mov ax,DSR0
 mov ss,ax
 mov esp,ebx
 mov ds,ax
 mov ax,cs
 and ax,3
 mov [r_cpl],ax
 mov ax,ss
 and ax,3
 mov [r_ssrpl],ax
 pushfd
 pop eax
 mov [r_efl],eax
 mov dx,2
 in al,dx
 mov [r_p02],al
 mov byte [r_stage],1
 mov dx,4
 in al,dx
 mov [r_p04],al
 mov byte [r_stage],2
 mov dx,0xED
 in al,dx
 mov [r_pED],al
 mov byte [r_stage],3
 mov dx,0x83
 in al,dx
 mov [r_p83],al
 mov byte [r_stage],4
pmret:
 sub sp,36
 mov bp,sp
 xor eax,eax
 mov dword [bp+0],rmentr
 mov ax,[segcs]
 mov [bp+4],eax
 mov dword [bp+8],2
 mov [bp+12],ebx
 mov ax,[segds]
 mov [bp+16],eax
 mov [bp+20],eax
 mov [bp+24],eax
 xor eax,eax
 mov [bp+28],eax
 mov [bp+32],eax
 clts
 mov ax,FLATSEL
 mov ds,ax
 mov ax,0xDE0C
 db 0x66,0x36,0xFF,0x1E
 dw vcpiv
rmentr:
 sti
 mov dx,s_pm
 call puts
 mov dx,s_cpl
 call puts
 mov ax,[r_cpl]
 call hex16
 mov dx,s_ss
 call puts
 mov ax,[r_ssrpl]
 call hex16
 mov dx,s_efl
 call puts
 mov eax,[r_efl]
 call hex32
 call crlf
 mov dx,s_pmbat
 call puts
 mov al,[r_p02]
 call hexb
 mov dl,' '
 call putc
 mov al,[r_p04]
 call hexb
 mov dl,' '
 call putc
 mov al,[r_pED]
 call hexb
 mov dl,' '
 call putc
 mov al,[r_p83]
 call hexb
 call crlf
 mov dx,s_stage
 call puts
 mov al,[r_stage]
 call hexb
 mov dx,s_gp
 call puts
 mov eax,[r_gperr]
 call hex32
 mov dl,'@'
 call putc
 mov ax,[r_gpcs]
 call hex16
 mov dl,':'
 call putc
 mov eax,[r_gpeip]
 call hex32
 mov dx,s_vec
 call puts
 mov al,[r_gpn]
 call hexb
 call crlf
 mov dx,s_v86b
 call puts
 mov di,r_v2
 call battery
 call printbat
 mov dx,s_cb
 call puts
 mov ax,[cbcnt]
 call hex16
 mov dx,s_cbport
 call puts
 mov ax,[cbport]
 call hex16
 call crlf
 mov ax,0x4C00
 int 0x21

; ---------------------------------------------------------------
gph:                         ; #GP / #PF in PM client, 32-bit gate frame
 pop eax
 mov [r_gperr],eax
 pop eax
 mov [r_gpeip],eax
 pop eax
 mov [r_gpcs],ax
 mov byte [r_gpn],0x0D
 jmp pmret
defint:
 o32 iret

; ---------------------------------------------------------------
battery:                     ; di -> 4 bytes result
 mov dx,2
 in al,dx
 mov [di],al
 mov dx,4
 in al,dx
 mov [di+1],al
 mov dx,0xED
 in al,dx
 mov [di+2],al
 mov dx,0x83
 in al,dx
 mov [di+3],al
 ret
printbat:
 push si
 mov si,di
 mov cx,4
.l:
 lodsb
 call hexb
 mov dl,' '
 call putc
 loop .l
 pop si
 call crlf
 ret

qpiinit:
 xor di,di
 mov es,di
 mov ax,0x1684
 mov bx,0x4354
 int 0x2F
 cmp al,0
 je .have
 mov dx,s_noqpi
 call puts
 mov ax,0x4C04
 int 0x21
.have:
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
 jnc .ok
 mov dx,s_trapfail
 call puts
.ok:
 push cs
 pop es
 ret

cb:
 pushad
 push ds
 push cs
 pop ds
 mov bp,sp
 inc word [cbcnt]
 mov ax,[bp+2+20]
 mov [cbport],ax
 test byte [bp+2+24],4
 jnz .done
 mov dword [bp+2+28],0xA5A5A5A5
.done:
 pop ds
 popad
 clc
 retf

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
hex32: push eax
 shr eax,16
 call hex16
 pop eax
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
.pp: push dx
 mov dl,al
 call putc
 pop dx
 ret

s_novcpi db 'DE00 failed AX=$'
s_de01 db 'DE01 failed',13,10,'$'
s_v86a db 'V86 before IN 02/04/ED/83: $'
s_v86b db 'V86 after  IN 02/04/ED/83: $'
s_pm db 'PM client:',13,10,'$'
s_cpl db ' CS.RPL=$'
s_ss db ' SS.RPL=$'
s_efl db ' EFLAGS=$'
s_pmbat db ' IN 02/04/ED/83: $'
s_stage db ' last stage completed=$'
s_gp db ' GP/PF err=$'
s_vec db ' vec=$'
s_cb db 'QPI callback count=$'
s_cbport db ' last port=$'
s_noqpi db 'no QPI',13,10,'$'
s_trapfail db 'trap 02 failed',13,10,'$'

part db 0
de00 dw 0
ptseg dw 0
segcs dw 0
segds dw 0
cbcnt dw 0
cbport dw 0
qpi dd 0
r_v1 db 0,0,0,0
r_v2 db 0,0,0,0
r_cpl dw 0xFFFF
r_ssrpl dw 0xFFFF
r_efl dd 0
r_p02 db 0xEE
r_p04 db 0xEE
r_pED db 0xEE
r_p83 db 0xEE
r_stage db 0
r_gpn db 0
r_gperr dd 0
r_gpeip dd 0
r_gpcs dw 0

align 8
gdt:
 dq 0
restab: times 3 dq 0
pmcs: dw 0xFFFF,0
 db 0,0x9A,0,0
pmds: dw 0xFFFF,0
 db 0,0x92,0,0
pmflat: dw 0xFFFF,0
 db 0,0x92,0x8F,0
pmtr: dw 0x68-1,0
 db 0,0x89,0,0
gdtend:

pdgdt: dw gdtend-gdt-1
gdtbase: dd gdt
pdidt: dw 256*8-1
idtbase: dd idt

vcpiv:
vcpiofs: dd 0
 dw 0x08
 dw 0

msw:
m_cr3 dd 0
m_gdtr dd pdgdt
m_idtr dd pdidt
 dw 0
 dw TRSEL
 dd pmentry
 dd CSR0

taskseg: times 0x68 db 0
align 8
idt: times 256*8 db 0
