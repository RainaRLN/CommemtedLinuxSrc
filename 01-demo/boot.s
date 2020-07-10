.globl begtext, begdata, begbss, endtext, enddata, endbss  ; 全局标识符, 供ld86链接使用
.text  ; 将当前段切换到正文段
begtext:
.data  ; 将当前段切换到数据段
begdata:
.bss  ; 将当前段切换到未初始化数据段
begbss:
; .text .data .bss 三段重叠，不分段

.text  ; 切换到正文段
BOOTSEG = 0x07c0  ; 启动时BIOS会将引导扇区(本程序)加载到0x7c00处

entry start  ; 告诉链接器, 程序从start标号开始执行
start:
    jmpi go, BOOTSEG  ; 段间跳转, CS=BOOTSEG, IP=go, CS:IP=0x07c0:0x0000
                      ; 当前处于实模式, CS:IP代表 CS<<4+IP, 即跳转到0x7c00 
go:
    mov ax, cs  ; 用段寄存器cs的值初始化数据段寄存器ds和es
    mov ds, ax
    mov es, ax

    mov [msgl+18], ah  ; ah为ax高位0x07, 0x07为BEL的ASCII, 替换msgl的最后一个点, 喇叭会鸣一声
    mov cx, #21  ; msgl长度为20, 显示20个字符
    mov dx, #0x1214  ; 字符将显示在屏幕第19行、第17列处(0x12-18, 0x10-16)
    mov bx, #0x0004  ; 字符显示属性(黑底红色)
    mov bp, #msgl  ; 指向要显示的字符串(供中断调用), es:bp 指向字符串
    mov ax, #0x1301  ; 写字符串并移动光标到串结尾处, ah=0x13->显示字符串 al=0x01->光标跟随移动

    int 0x10  ; 调用0x10中断, 功能0x13, 子功能0x01 显示字符

loopl:
    jmp loopl  ; 死循环

msgl:
    .ascii "Loading system ...."  ; 会自动添加NULL字符(为字符串结束标志, 不用于显示)
    .byte 13, 10  ; 

.org 510  ; 修改当前汇编地址为510(0x1FE)
    .word 0xAA55  ; 有效引导扇区标志, 供BIOS加载引导扇区使用
; 510+2 正好512字节
.text
endtext:
.data
enddata:
.bss
endbss:
