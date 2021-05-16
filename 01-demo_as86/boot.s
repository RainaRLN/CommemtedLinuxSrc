

entry start

start:
    jmpi go, 0x07c0

go:
    mov ax, cs  ; 使ds es指向与cs相同的段,以便对数据进行操作时能定位到正确位置
    mov ds, ax
    mov es, ax

display:
    mov cx, #21  ; msgl长度为20, 显示20个字符
    mov dx, #0x1214  ; 字符将显示在屏幕第19行、第17列处(0x12-18, 0x10-16)
    mov bx, #0x0004  ; 字符显示属性(黑底红色)
    mov bp, #msgl  ; 指向要显示的字符串(供中断调用), es:bp 指向字符串
    mov ax, #0x1301  ; 写字符串并移动光标到串结尾处, ah=0x13->显示字符串 al=0x01->光标跟随移动

    int 0x10  ; 调用0x10中断, 功能0x13, 子功能0x01 显示字符

loopl:
    hlt  ; 休眠
    jmp loopl  ; 死循环

msgl:
    .ascii "Loading system ...."  ; 会自动添加NULL字符(为字符串结束标志, 不用于显示)
    .byte 13, 10  ; 回车, 换行

.org 510  ; 修改当前汇编地址为510(0x1FE)
    .word 0xAA55  ; 有效引导扇区标志, 供BIOS加载引导扇区使用, 若结尾不是0xAA55, 计算机会认为无有效启动程序
; 510+2 正好512字节
