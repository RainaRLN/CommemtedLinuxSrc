
    org 07c00h  ; 将代码加载到内存地址0x7c00处
    
go:
    mov ax, cs  ; 使ds es指向与cs相同的段,以便对数据进行操作时能定位到正确位置
    mov ds, ax
    mov es, ax

display:
    mov cx, 21  ; msgl长度为20, 显示20个字符
    mov dx, 01214h  ; 字符将显示在屏幕第19行、第17列处(0x12-18, 0x10-16)
    mov bx, 0004h  ; 字符显示属性(黑底红色)
    mov bp, msgl  ; 指向要显示的字符串(供中断调用), es:bp 指向字符串
    mov ax, 01301h  ; 写字符串并移动光标到串结尾处, ah=0x13->显示字符串 al=0x01->光标跟随移动

    int 10h  ; 调用0x10中断, 功能0x13, 子功能0x01 显示字符

loopl:
    hlt  ; 休眠
    jmp loopl  ; 死循环

msgl:
    db "Loading system ...."  ; 会自动添加NULL字符(为字符串结束标志, 不用于显示)
    db 13, 10  ; 

times 510-($-$$) db 0  ;  $->当前行地址; $$->当前section起始地址; 填充0 510-($-$$)次, 即填充0到510字节为止
dw 0xaa55  ; 结束标志
