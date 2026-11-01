; FAKEPCI.COM - minimal PCI BIOS (INT 1Ah B1xx) with one fake YMF744 (1073:000D) at bus0 dev0Bh fn0 (BX=0058h).
; Config space = 256-byte RAM array; config writes are logged. FAKEPCI = install, FAKEPCI /D = dump.
cpu 386
org 0x100
start:
    jmp init
old1a: dd 0
logn:  dw 0
logb:  times 64*4 db 0       ; entries: word0 = reg | size<<12 , word1 = low 16 bits of value
cfg:   times 256 db 0

isr:
    cmp ax,0xB101
    je present
    cmp ax,0xB102
    je find
    cmp ax,0xB1FE
    je dump
    cmp ah,0xB1
    jne chain
    cmp al,0x08
    jb chain
    cmp al,0x0D
    ja chain
    cmp bx,0x0058
    jne badbus
    push bx
    push si
    movzx si,di             ; SI = reg offset (DI low byte)
    and si,0xFF
    cmp al,0x08
    je rb
    cmp al,0x09
    je rw
    cmp al,0x0A
    je rd
    cmp al,0x0B
    je wb
    cmp al,0x0C
    je ww
    jmp wd
rb: mov cl,[cs:cfg+si]
    jmp okp
rw: mov cx,[cs:cfg+si]
    jmp okp
rd: mov ecx,[cs:cfg+si]
    jmp okp
wb: mov [cs:cfg+si],cl
    mov bx,1
    jmp dolog
ww: mov [cs:cfg+si],cx
    mov bx,2
    jmp dolog
wd: mov [cs:cfg+si],ecx
    mov bx,4
dolog:
    push ax
    push di
    mov ax,[cs:logn]
    cmp ax,60
    jae nolog
    mov di,ax
    shl di,2
    shl bx,12
    or bx,si
    mov [cs:logb+di],bx
    mov [cs:logb+di+2],cx
    inc word [cs:logn]
nolog:
    pop di
    pop ax
okp:
    pop si
    pop bx
    xor ah,ah
    clc
    jmp ret_
badbus:
    mov ah,0x87
    stc
    jmp ret_
present:
    xor ah,ah
    mov al,0x01
    mov bx,0x0210
    xor cx,cx
    mov edx,0x20494350
    clc
    jmp ret_
find:
    cmp dx,0x1073
    jne nf
    cmp cx,0x000D
    jne nf
    or si,si
    jne nf
    mov bx,0x0058
    xor ah,ah
    clc
    jmp ret_
nf: mov ah,0x86
    stc
ret_:
    push bp
    mov bp,sp
    jc setc
    and word [bp+6],0xFFFE
    pop bp
    iret
setc:
    or word [bp+6],1
    pop bp
    iret
dump:
    push cs
    pop es
    mov bx,cfg
    mov cx,logn
    mov ax,0xFEED
    iret
chain:
    jmp far [cs:old1a]

init:
    mov byte [cfg+0],0x73
    mov byte [cfg+1],0x10
    mov byte [cfg+2],0x0D
    mov byte [cfg+8],0x03
    mov byte [cfg+0x0A],0x01
    mov byte [cfg+0x0B],0x04
    mov word [cfg+0x40],0x907F
    mov byte [cfg+0x3C],0x05
    mov byte [cfg+0x3D],0x01
    mov si,0x81
sk: lodsb
    cmp al,' '
    je sk
    cmp al,'/'
    jne inst
    lodsb
    or al,0x20
    cmp al,'d'
    jne inst
    mov ax,0xB1FE
    int 0x1A
    cmp ax,0xFEED
    jne nores
    mov si,bx
    add si,0x38
    mov bp,0x38
row:
    mov ax,bp
    call hexb
    mov dl,':'
    call putc
col:
    mov al,[es:si]
    call hexb
    mov dl,' '
    call putc
    inc si
    inc bp
    test bp,7
    jnz col
    call crlf
    cmp bp,0x50
    jb row
    mov dx,msgn
    call puts
    mov si,cx
    mov bp,[es:si]
    mov ax,bp
    call hexb
    call crlf
    add si,2
wl: or bp,bp
    jz fin
    mov dx,msgw
    call puts
    mov ax,[es:si]
    shr ax,12
    call hexn2
    mov dl,' '
    call putc
    mov ax,[es:si]
    and ax,0xFF
    call hexb
    mov dl,'='
    call putc
    mov ax,[es:si+2]
    push ax
    mov al,ah
    call hexb
    pop ax
    call hexb
    call crlf
    add si,4
    dec bp
    jmp wl
fin: mov ax,0x4C00
    int 0x21
nores:
    mov dx,msgnr
    call puts
    mov ax,0x4C01
    int 0x21
inst:
    mov ax,0x351A
    int 0x21
    mov [old1a],bx
    mov [old1a+2],es
    mov dx,isr
    mov ax,0x251A
    int 0x21
    mov dx,msgi
    call puts
    mov dx,init
    add dx,15
    shr dx,4
    mov ax,0x3100
    int 0x21
putc: mov ah,2
    int 0x21
    ret
puts: mov ah,9
    int 0x21
    ret
crlf: mov dl,13
    call putc
    mov dl,10
    jmp putc
hexb: push ax
    shr al,4
    call hexn
    pop ax
hexn2: and al,0xF
hexn: and al,0xF
    add al,'0'
    cmp al,'9'
    jbe pp
    add al,7
pp: mov dl,al
    jmp putc
msgi: db 'FAKEPCI installed (1073:000D @ 0:0B:0)',13,10,'$'
msgnr: db 'FAKEPCI not resident',13,10,'$'
msgn: db 'write log entries: $'
msgw: db 'W size=$'
