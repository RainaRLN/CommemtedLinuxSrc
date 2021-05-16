; 加载head.s -> 将内核代码搬移到0x0处 -> 加载GDT\IDT -> 跳转到0x0处

BOOTSEG = 0x07c0  ; 开机后BIOS将自动加载引导扇区(本程序)至0x7C00处
SYSSEG = 0x1000  ; 可该其他值
SYSLEN = 17  ; 内存占用的最大磁盘扇区数

entry start
start:
    jmpi go, BOOTSEG  ; 0x07c0:go
go:
    mov ax, cs  ; cs\ds\ss均指向0x7c0段
    mov ds, ax
    mov	es, ax
    mov ss, ax
    mov sp, #0x400  ; 设置临时栈指针, 其值大于程序末端并有一定空间即可, 本程序大小为512(0x200)

load_system:  ; 加载内核代码, 即head.s的代码; 从磁头0-柱面0-扇区2搬移head.s程序到内存0x10000处
    mov dx, #0x0000  ; dh磁头号, dl驱动器号
    mov cx, #0x0002  ; ch柱面号低8位, cl[7:6]柱面号高2位; CL[5:0]起始扇区号(从1计)
    mov ax, #SYSSEG
    mov es, ax  ; es=0x1000
    xor bx, bx  ; es:bx->读取缓冲区位置, 将head代码搬到内存0x1000:0x0000处
    mov ax, #0x200+SYSLEN  ; ah=0x02->功能2读扇区, al=SETUPLEN要读的扇区数量
    int 0x13  ; BIOS读磁盘中断0x13
    jnc ok_load_system  ; 0x13中断返回值: CF=0 -> 成功; CF=1->错误, 错误码存放在AH中; jnc->CF=0跳转
    jmp load_system

ok_load_system:  ; 把内核代码搬移到0x00000处
    cli  ; 关中断
    mov ax, #SYSSEG
    mov ds, ax  ; ds=0x1000
    xor ax, ax
    mov es, ax
    mov cx, #0x1000  ; 移动4KB次, 每次一个word
    xor si, si  ; ds:si=0x1000:0x0000->源地址
    xor di, di  ; es:di=0x0000:0x0000
    rep 
    movw  ; 重复执行移动指令

; 加载IDT和GDT基地址寄存器IDTR和GDTR, 这里设置的为临时GDT\IDT, 为的是进入保护模式后跳转到0x0运行
    mov ax, #BOOTSEG
    mov ds, ax  ; ds=0x7c0
    lidt idt_48  ; 加载IDTR, 6字节操作数: 2字节表长度+4字节线性基地址
    lgdt gdt_48  ; 加载GDTR, 6字节操作数: 2字节表长度+4字节线性基地址

; 进入保护模式, 跳转到0x0000:0x0000=0x00000000处
    mov ax, #0x0001  ; CR[0]为PE标志位, 用于设置保护模式
    lmsw ax  ; 加载机器状态字
    jmpi 0, 8  ; cs=00001000B->cs[15:3]为描述符索引index=1, 选择第1个描述符, 段基地址为0x0000; cs[2]为0选择GDT,1选择IDT; cs[1:0]请求特权级, 0级最高

; 设置全局描述符表GDT的内容, 设置3个段描述符, dummy\代码段\数据段
gdt:  
    ; GDT描述符组成: www.cnblogs.com/raina/p/11720824.html
    .word 0, 0, 0, 0  ; dummy 段描述符0, 不使用

    .word 0x07FF  ; Limit=0x007FF, 2048*4KB=8MB
    .word 0x0000  ; 段基地址Base=0x00000000
    .word 0x9A00  ; Type=0x1010->代码段, 可执行/可读
    .word 0x00C0  ; G=1, 长度单位为4KB

    .word 0x07FF  ; Limit=0x007FF, 2048*4KB=8MB
    .word 0x0000  ; 段基地址Base=0x00000000
    .word 0x9200  ; Type=0x0010->数据段, 可读/可写
    .word 0x00C0  ; G=1, 长度单位为4KB

idt_48:
    .word 0  ; IDT长度0
    .word 0, 0  ; IDT表的线性基地址0

gdt_48:
    .word 0x7ff  ; GDT表长度2KB, 一个描述符项大小8B, 可容纳2048/8=256个描述符项
    .word 0x7c00+gdt, 0  ; GDT表的线性基地址在0x7c0:gdt处

.org 510
    .word 0xAA55
