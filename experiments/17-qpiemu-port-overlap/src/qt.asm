; QT.COM - QPIEMU (Jemm JLM) vs Jemm's own DMA port traps. Usage: QT A | QT B
; A = delivery battery + special tests, B = timing. Output on stdout (redirect to a file).
cpu 386
bits 16
org 0x100
MAXREC equ 40
RECSZ  equ 24

%macro BEG 1
 mov word [lbl], %1
 call begin
%endmacro
%macro OP 2+
 BEG %1
 %2
 call report
%endmacro

start:
 mov al,[0x82]
 mov [part],al
 mov ax,1684h
 mov bx,4354h
 xor di,di
 mov es,di
 int 2Fh
 cmp al,0
 jne noqpi
 mov [qpi],di
 mov [qpi+2],es
 mov dx,s_entry
 call puts
 mov ax,es
 call hex16
 mov dl,':'
 call putc
 mov ax,di
 call hex16
 call crlf
 mov ah,3
 call far [qpi]
 mov dx,s_ver
 call puts
 mov ax,bx
 call hex16
 call crlf
 mov ax,1A06h
 call far [qpi]
 mov [oldcb],di
 mov [oldcb+2],es
 mov dx,s_oldcb
 call puts
 mov ax,es
 call hex16
 mov dl,':'
 call putc
 mov ax,di
 call hex16
 call crlf
 push cs
 pop es
 mov di,cb
 mov ax,1A07h
 call far [qpi]
 call setcf
 mov dx,s_setcb
 call puts
 call prcf
 push cs
 pop es
 mov byte [mode],0
 mov byte [pcap],6
 cmp byte [part],'Q'
 je done
 cmp byte [part],'B'
 je partB
 cmp byte [part],'S'
 je partS
 jmp partA

noqpi:
 mov dx,s_noqpi
 call puts
 mov ax,0x4C01
 int 0x21

;---------------- part A
partA:
 mov si,listA
 call traplist
 cmp byte [part],'T'
 je fin
 ; double install of port 2
 mov dx,s_dbl
 call puts
 mov dx,2
 mov ax,1A09h
 call far [qpi]
 call setcf
 call prcf

 cmp byte [part],'D'
 je fin
 cmp byte [part],'R'
 jne .nr
 mov dx,2
 BEG s_rod
 mov si,bufA
 mov cx,2
 rep outsd
 call report
 jmp fin
.nr:
 mov al,[part]
 sub al,'0'
 cmp al,10
 ja .all
 movzx bx,al
 add bx,bx
 mov dx,[battports+bx]
 call battery
 jmp fin
.all:
 cmp byte [part],'E'
 je fin
 ; S1: Jemm's ISA_DMA_Traphandler pre-emption (mask/mode writes)
 mov dx,s_s1
 call puts
 mov dx,0x0B
 BEG s_o0b55
 mov al,0x55
 out dx,al
 call report
 BEG s_o0b56
 mov al,0x56
 out dx,al
 call report
 BEG s_o0b54
 mov al,0x54
 out dx,al
 call report
 mov dx,0x0A
 BEG s_o0a01
 mov al,0x01
 out dx,al
 call report
 BEG s_o0a02
 mov al,0x02
 out dx,al
 call report
 BEG s_o0a06
 mov al,0x06
 out dx,al
 call report
 BEG s_o0a00
 mov al,0x00
 out dx,al
 call report
 BEG s_o0a04
 mov al,0x04
 out dx,al
 call report
 BEG s_o0a05
 mov al,0x05
 out dx,al
 call report
 BEG s_o0a07
 mov al,0x07
 out dx,al
 call report
 mov dx,0x0F
 BEG s_o0f0f
 mov al,0x0F
 out dx,al
 call report

 ; S2: passthrough via 1A04 and readback of ch1 regs
 mov byte [mode],1
 mov byte [pcap],14
 BEG s_s2
 mov dx,0x0C
 out dx,al
 mov dx,2
 mov al,0x34
 out dx,al
 mov al,0x12
 out dx,al
 mov dx,3
 mov al,0xFF
 out dx,al
 mov al,0x00
 out dx,al
 mov dx,0x83
 mov al,0x5A
 out dx,al
 mov dx,0x0C
 out dx,al
 mov dx,2
 in al,dx
 mov bl,al
 in al,dx
 mov bh,al
 mov dx,3
 in al,dx
 mov cl,al
 in al,dx
 mov ch,al
 mov dx,0x83
 in al,dx
 mov [v0],al
 mov [r0],bx
 mov [r1],cx
 call report
 mov dx,s_s2r
 call puts
 mov ax,[r0]
 call hex16
 mov dl,' '
 call putc
 mov ax,[r1]
 call hex16
 mov dl,' '
 call putc
 mov al,[v0]
 call hexb
 call crlf
 mov byte [mode],0
 mov byte [pcap],6

 ; S4: untrap port 2 -> goes back to Jemm?
 mov dx,s_s4
 call puts
 mov dx,2
 mov ax,1A0Ah
 call far [qpi]
 call setcf
 call prcf
 mov dx,2
 BEG s_inb_untr
 mov eax,0x11111111
 in al,dx
 call report

 ; S3: 1A00/1A01 vs normal IN (page registers; 83 untrapped first)
 mov dx,s_s3
 call puts
 mov dx,0x83
 mov ax,1A0Ah
 call far [qpi]
 call setcf
 call prcf
 mov dx,0x83
 call pagetest
 mov dx,0x82
 call pagetest
 mov dx,0x87
 call pagetest
 mov dx,s_cnt
 call puts
 mov ax,[count]
 call hex16
 call crlf

 fin: mov si,listA
 call untraplist
 jmp done

;---------------- part B (timing)
partB:
 mov si,listB
 call traplist
 mov dx,s_tim
 call puts
 mov dx,0x80
 mov bx,1000
 call timeit
 mov dx,0x81
 mov bx,100
 call timeit
 mov dx,0x08
 mov bx,100
 call timeit
 mov dx,0x08
 mov bx,100
 call timeit
 mov dx,s_cnt
 call puts
 mov ax,[count]
 call hex16
 call crlf
 mov si,listB
 call untraplist
 jmp done

;---------------- part S: REP OUTSD with NO QPI trap (control: Jemm alone)
partS:
 mov dx,0x80
 BEG s_rod80
 mov si,bufA
 mov cx,2
 rep outsd
 call report
 mov dx,2
 BEG s_rod02
 mov si,bufA
 mov cx,2
 rep outsd
 call report
 jmp done

done:
 ; restore old callback
 mov di,[oldcb]
 mov es,[oldcb+2]
 mov ax,1A07h
 call far [qpi]
 mov dx,s_done
 call puts
 mov ax,0x4C00
 int 0x21

;---------------- helpers
timeit:                       ; dx=port, bx=outer(x10000) ; prints
 push bx
 push dx
 xor ax,ax
 mov es,ax
 mov si,[es:0x46C]
.w: mov ax,[es:0x46C]
 cmp ax,si
 je .w
 mov si,ax
.o: mov cx,[inn]
.i: out dx,al
 dec cx
 jnz .i
 dec bx
 jnz .o
 mov ax,[es:0x46C]
 sub ax,si
 push cs
 pop es
 push ax
 mov dx,s_tport
 call puts
 mov bp,sp
 mov dx,[bp+2]
 mov al,dl
 call hexb
 mov dx,s_tout
 call puts
 mov ax,[bp+4]
 call hex16
 mov dx,s_ttick
 call puts
 pop ax
 call hex16
 call crlf
 pop dx
 pop bx
 ret

pagetest:                     ; dx=port
 mov [pt],dx
 mov al,0x5A
 out dx,al
 in al,dx
 mov [v0],al
 mov ax,1A00h
 call far [qpi]
 mov [v1],bl
 mov dx,[pt]
 mov ax,1A01h
 mov bl,0x3C
 call far [qpi]
 mov dx,[pt]
 in al,dx
 mov [v2],al
 mov ax,1A00h
 call far [qpi]
 mov [v3],bl
 mov dx,s_pt
 call puts
 mov al,[pt]
 call hexb
 mov dx,s_pt1
 call puts
 mov al,[v0]
 call hexb
 mov dl,' '
 call putc
 mov al,[v1]
 call hexb
 mov dx,s_pt2
 call puts
 mov al,[v2]
 call hexb
 mov dl,' '
 call putc
 mov al,[v3]
 call hexb
 call crlf
 mov dx,[pt]
 xor al,al
 out dx,al
 ret

battery:                      ; dx=port
 mov [bport],dx
 push dx
 mov dx,s_hdr
 call puts
 pop dx
 mov al,dl
 call hexb
 call crlf
 mov dx,[bport]
 BEG s_outb
 mov eax,0x11111155
 out dx,al
 call report
 BEG s_inb
 mov eax,0x11111111
 in al,dx
 call report
 BEG s_outw
 mov eax,0x11112255
 out dx,ax
 call report
 BEG s_inw
 mov eax,0x11111111
 in ax,dx
 call report
 BEG s_outd
 mov eax,0x44332255
 out dx,eax
 call report
 BEG s_ind
 mov eax,0x11111111
 in eax,dx
 call report
 BEG s_rob
 mov si,bufA
 mov cx,3
 rep outsb
 call report
 BEG s_rib
 mov di,bufB
 mov cx,3
 rep insb
 call report
 BEG s_row
 mov si,bufA
 mov cx,2
 rep outsw
 call report
 BEG s_riw
 mov di,bufB
 mov cx,2
 rep insw
 call report
 BEG s_ob1
 mov si,bufA
 outsb
 call report
 BEG s_ib1
 mov di,bufB
 insb
 call report
 ret

traplist:                     ; si=list of ports (0-term)
 lodsw
 or ax,ax
 jz .d
 push si
 mov dx,ax
 mov [pt],dx
 mov ax,1A09h
 call far [qpi]
 call setcf
 mov dx,s_trap
 call puts
 mov al,[pt]
 call hexb
 call prcf
 pop si
 jmp traplist
.d: ret

untraplist:
 lodsw
 or ax,ax
 jz .d
 push si
 mov dx,ax
 mov [pt],dx
 mov ax,1A0Ah
 call far [qpi]
 call setcf
 mov dx,s_untrap
 call puts
 mov al,[pt]
 call hexb
 call prcf
 pop si
 jmp untraplist
.d: ret

setcf:                        ; flags->[cf]
 pushf
 pop ax
 and al,1
 mov [cf],al
 ret
prcf:
 mov dx,s_cf
 call puts
 mov al,[cf]
 call hexb
 call crlf
 ret

begin:
 mov word [wp],recbuf
 mov word [count],0
 ret

report:
 pushad
 mov bp,sp
 mov dx,[lbl]
 call puts
 mov dx,s_n
 call puts
 mov ax,[count]
 call hex16
 mov dx,s_eax
 call puts
 mov eax,[bp+28]
 call hex32
 mov dx,s_ecx
 call puts
 mov eax,[bp+24]
 call hex32
 mov dx,s_si
 call puts
 mov ax,[bp+4]
 call hex16
 mov dx,s_di
 call puts
 mov ax,[bp]
 call hex16
 call crlf
 mov si,recbuf
 mov cx,[count]
 cmp cx,MAXREC
 jbe .a
 mov cx,MAXREC
.a: movzx ax,byte [pcap]
 cmp cx,ax
 jbe .l
 mov cx,ax
.l: or cx,cx
 jz .done
 push cx
 mov dx,s_rec
 call puts
 mov ax,[si]
 call hex16
 mov dx,s_rdx
 call puts
 mov ax,[si+2]
 call hex16
 mov dx,s_reax
 call puts
 mov eax,[si+4]
 call hex32
 mov dx,s_recx
 call puts
 mov eax,[si+8]
 call hex32
 mov dx,s_rebx
 call puts
 mov eax,[si+12]
 call hex32
 mov dx,s_resi
 call puts
 mov eax,[si+16]
 call hex32
 mov dx,s_redi
 call puts
 mov eax,[si+20]
 call hex32
 call crlf
 add si,RECSZ
 pop cx
 dec cx
 jmp .l
.done: popad
 ret

;---------------- QPI callback (far)
cb:
 pushad
 push ds
 push cs
 pop ds
 mov bp,sp
 cmp word [count],MAXREC
 jae .nolog
 mov di,[wp]
 mov ax,[bp+2+24]
 mov [di],ax
 mov ax,[bp+2+20]
 mov [di+2],ax
 mov eax,[bp+2+28]
 mov [di+4],eax
 mov eax,[bp+2+24]
 mov [di+8],eax
 mov eax,[bp+2+16]
 mov [di+12],eax
 mov eax,[bp+2+4]
 mov [di+16],eax
 mov eax,[bp+2+0]
 mov [di+20],eax
 add word [wp],RECSZ
.nolog:
 inc word [count]
 cmp byte [mode],1
 je .pass
 test byte [bp+2+24],4
 jnz .done
 mov dword [bp+2+28],0xA5A5A5A5
 jmp .done
.pass:
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
 push ax
 push bx
 mov ah,0x68
 mov bx,1
 int 0x21
 pop bx
 pop ax
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
 jbe pp
 add al,7
pp: push dx
 mov dl,al
 call putc
 pop dx
 ret

; data
qpi dd 0
inn dw 1000
oldcb dd 0
lbl dw 0
wp dw recbuf
count dw 0
mode db 0
pcap db 6
part db 0
cf db 0
v0 db 0
v1 db 0
v2 db 0
v3 db 0
r0 dw 0
r1 dw 0
pt dw 0
bport dw 0
bufA db 0x34,0x12,0x99,0x77,0x11,0x22,0x33,0x44
bufB times 8 db 0
listA dw 0x02,0x03,0x83,0x0A,0x0B,0x0C,0x0F,0xC4,0x08,0x09,0xC0,0xD0,0
battports dw 0x02,0x03,0x83,0x0A,0x0B,0x0C,0xC4,0x08,0x09,0xC0,0xD0,0
listB dw 0x08,0
s_entry db 'QPI entry $'
s_ver db 'QPI ver BX=$'
s_oldcb db 'old callback $'
s_setcb db '1A07 set callback $'
s_noqpi db 'no QPI$'
s_trap db '1A09 trap port $'
s_untrap db '1A0A untrap port $'
s_cf db ' CF=$'
s_dbl db '1A09 again on port 02 (already ours) $'
s_hdr db '== port $'
s_s1 db '== S1 mask/mode writes (ch2 pre-emption?)',13,10,'$'
s_s2 db 'S2 passthrough ch1 program+readback$'
s_s3 db '== S3 1A00/1A01 vs normal IN',13,10,'$'
s_s4 db '== S4 untrap port 2 $'
s_s2r db 'S2 readback addr(02x2)=$'
s_pt db 'port $'
s_pt1 db ' write5A: normalIN/1A00=$'
s_pt2 db ' ; after 1A01=3C: normalIN/1A00=$'
s_cnt db 'callbacks total=$'
s_tim db '== timing (1000 OUT per outer)',13,10,'$'
s_tport db 'port $'
s_tout db ' outer=$'
s_ttick db ' ticks=$'
s_done db 'DONE',13,10,'$'
s_n db ' n=$'
s_eax db ' eax=$'
s_ecx db ' ecx=$'
s_si db ' si=$'
s_di db ' di=$'
s_rec db '    cb cx=$'
s_rdx db ' dx=$'
s_reax db ' eax=$'
s_recx db ' ecx=$'
s_rebx db ' ebx=$'
s_resi db ' esi=$'
s_redi db ' edi=$'
s_outb db '  OUT b$'
s_inb db '  IN b$'
s_outw db '  OUT w$'
s_inw db '  IN w$'
s_outd db '  OUT d$'
s_ind db '  IN d$'
s_rob db '  REP OUTSB cx3$'
s_rib db '  REP INSB cx3$'
s_row db '  REP OUTSW cx2$'
s_riw db '  REP INSW cx2$'
s_rod db '  REP OUTSD cx2$'
s_ob1 db '  OUTSB$'
s_ib1 db '  INSB$'
s_o0b55 db '  OUT 0B,55 (ch1 mode)$'
s_o0b56 db '  OUT 0B,56 (ch2 mode)$'
s_o0b54 db '  OUT 0B,54 (ch0 mode)$'
s_o0a01 db '  OUT 0A,01 unmask ch1$'
s_o0a02 db '  OUT 0A,02 unmask ch2$'
s_o0a06 db '  OUT 0A,06 mask ch2$'
s_o0a00 db '  OUT 0A,00 unmask ch0$'
s_o0a04 db '  OUT 0A,04 mask ch0$'
s_o0a05 db '  OUT 0A,05 mask ch1$'
s_o0a07 db '  OUT 0A,07 mask ch3$'
s_o0f0f db '  OUT 0F,0F mask all$'
s_inb_untr db '  IN b after untrap$'

s_rod80 db 'REP OUTSD cx2 port 80 (no trap anywhere)$'
s_rod02 db 'REP OUTSD cx2 port 02 (Jemm VDMA only)$'
recbuf times MAXREC*RECSZ db 0
