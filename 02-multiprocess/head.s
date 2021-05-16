.code32
.global startup_32

LATCH = 11932  # 8254芯片的时钟输入频率为1.193180MHz, 希望10ms一次中断, 定时器初始计数值应为 1193180Hz/100Hz ≈ 11932
SCRN_SEL = 0x18  # 屏幕显示内存段选择符
TSS0_SEL = 0x20  # 任务0的TSS段选择符
LDT0_SEL = 0x28  # 任务0的LDT段选择符
TSS1_SEL = 0x30  # 任务1的TSS段选择符
LDT1_SEL = 0x38  # 任务1的LDT段选择符

.text  # 切换到数据段
startup_32:
    movl $0x10, %eax  # 0x10为GDT中数据段选择符
    mov %ax, %ds
    lss init_stack, %esp

    call setup_idt  # 设置IDT
    call setup_gdt  # 设置GDT

# 改变GDT后重新加载所有段寄存器
    movl $0x10, %eax
    mov %ax, %ds
    mov %ax, %es
    mov %ax, %fs
    mov %ax, %gs
    lss init_stack, %esp

# 设置8253定时芯片
    movb $0x36, %al  # 控制字: 00->通道0, 11->先低后高, 011->工作方式3, 0->16bit二进制计数
    movl $0x43, %edx  # 0100 0011->写控制字
    outb %al, %dx
	movl $LATCH, %eax  # 计数器初值, 设置频率为100Hz
	movl $0x40, %edx  # 0100 0000->通道0
	outb %al, %dx  # 写初值低位
	movb %ah, %al
	outb %al, %dx  # 写初值高位

# setup timer & system call interrupt descriptors.
	movl $0x00080000, %eax	# 0x0008 为内核代码段选择符
	movw $timer_interrupt, %ax  # 把中断处理程序地址给ax, 设置定时中断门描述符
	movw $0x8E00, %dx  # 中断门类型14（屏蔽中断）, 特权级0或硬件使用
	movl $0x08, %ecx  # 开机后BIOS设置的默认时钟中断号为8
	lea idt(,%ecx,8), %esi  # 把IDT描述符0x08地址放入ESI中, 然后设置该描述符
	movl %eax,(%esi) 
	movl %edx,4(%esi)
	movw $system_interrupt, %ax  # 取系统调用处理程序地址, 设置系统调用陷阱门描述符
	movw $0xef00, %dx  # 陷阱门类型15, 特权级3的程序可执行
	movl $0x80, %ecx  # 系统调用向量号0x80
	lea idt(,%ecx,8), %esi  # 把IDT描述符项0x80地址放入ESI中, 然后设置该描述符
	movl %eax,(%esi)
	movl %edx,4(%esi)

# unmask the timer interrupt.
#	movl $0x21, %edx
#	inb %dx, %al
#	andb $0xfe, %al
#	outb %al, %dx

# 任务0
	pushfl  # 复位标志寄存器EFLAGS中的嵌套任务标志
	andl $0xffffbfff, (%esp)
	popfl
	movl $TSS0_SEL, %eax  # 把任务0的TSS段选择符加载到任务寄存器TR
	ltr %ax
	movl $LDT0_SEL, %eax  # 把任务0的LDT段选择符加载到局部描述符表寄存器LDTR
	lldt %ax   # TR和LDTR只需人工加载一次, 以后CPU会自动处理
	movl $0, current  # 把当前任务号0保存在current变量中
	sti  # 开启中断, 并在栈中营造中断返回场景
	pushl $0x17  # 把任务0当前局部空间数据段(堆栈段)选择符入栈
	pushl $init_stack  # 把堆栈指针入栈(也可以直接把ESP入栈)
	pushfl  # 把标志寄存器值入栈
	pushl $0x0f  # 把当前局部空间代码段选择符入栈
	pushl $task0  # 把代码指针入栈
	iret  # 执行中断返回命令, 切换到特权级3的任务0中执行

/****************************************/
# 设置GDT和IDT描述符
setup_gdt:
	lgdt lgdt_opcode  # 使用6字节操作数lgdt_opcode设置GDT表位置和长度
	ret

# 暂将IDT表中所有256个中断门描述符都设置为同一默认值, 均使用默认的中断处理过程 ignore_net
# 设置过程: 先在eax和edx寄存器对中分别设置默认中断门描述符的0~3字节和4~7字节内容, 
# 然后利用该寄存器对循环往IDT表中填充默认中断门描述符内容
setup_idt:
	lea ignore_int, %edx  # 
	movl $0x00080000, %eax  # 0x0008内核代码段选择符
	movw %dx, %ax		/* selector = 0x0008 = cs */
	movw $0x8E00, %dx  # 中断门类型, 特权级0	/* interrupt gate - dpl=0, present */
	lea idt, %edi
	mov $256, %ecx  # 循环次数
rp_sidt:  # 循环设置所有256个门描述符项
	movl %eax, (%edi)  
	movl %edx, 4(%edi)
	addl $8, %edi
	dec %ecx
	jne rp_sidt
	lidt lidt_opcode  # 最后用6字节操作数加载IDTR寄存器
	ret

# -----------------------------------
# 显示字符子程序
write_char:
	push %gs  # 保存要用到的寄存器, EAX由调用者负责保存
	pushl %ebx
#	pushl %eax
	mov $SCRN_SEL, %ebx  # 让GS指向显示内存段(0xb8000)
	mov %bx, %gs
	movl scr_loc, %ebx  # 从变量scr_loc中取目前显示的位置
	shl $1, %ebx  # 每个字符占两字节, 其中一个为属性字节, 因此实际显示位置为对应的显示内存偏移地址*2
	movb %al, %gs:(%ebx)  # 
	shr $1, %ebx
	incl %ebx
	cmpl $2000, %ebx
	jb 1f
	movl $0, %ebx
1:	movl %ebx, scr_loc	
#	popl %eax
	popl %ebx
	pop %gs
	ret

/***********************************************/
/* This is the default interrupt "handler" :-) */
.align 2
ignore_int:
	push %ds
	pushl %eax
	movl $0x10, %eax
	mov %ax, %ds
	movl $67, %eax            /* print 'C' */
	call write_char
	popl %eax
	pop %ds
	iret

/* Timer interrupt handler */ 
.align 2
timer_interrupt:
	push %ds
	pushl %eax
	movl $0x10, %eax
	mov %ax, %ds
	movb $0x20, %al
	outb %al, $0x20
	movl $1, %eax
	cmpl %eax, current
	je 1f
	movl %eax, current
	ljmp $TSS1_SEL, $0
	jmp 2f
1:	movl $0, current
	ljmp $TSS0_SEL, $0
2:	popl %eax
	pop %ds
	iret

/* system call handler */
.align 2
system_interrupt:
	push %ds
	pushl %edx
	pushl %ecx
	pushl %ebx
	pushl %eax
	movl $0x10, %edx
	mov %dx, %ds
	call write_char
	popl %eax
	popl %ebx
	popl %ecx
	popl %edx
	pop %ds
	iret

/*********************************************/
current:.long 0
scr_loc:.long 0

.align 2
lidt_opcode:
	.word 256*8-1		# idt contains 256 entries
	.long idt		# This will be rewrite by code. 
lgdt_opcode:
	.word (end_gdt-gdt)-1	# so does gdt 
	.long gdt		# This will be rewrite by code.

	.align 8
idt:	.fill 256,8,0		# idt is uninitialized

gdt:	.quad 0x0000000000000000	/* NULL descriptor */
	.quad 0x00c09a00000007ff	/* 8Mb 0x08, base = 0x00000 */
	.quad 0x00c09200000007ff	/* 8Mb 0x10 */
	.quad 0x00c0920b80000002	/* screen 0x18 - for display */

	.word 0x0068, tss0, 0xe900, 0x0	# TSS0 descr 0x20
	.word 0x0040, ldt0, 0xe200, 0x0	# LDT0 descr 0x28
	.word 0x0068, tss1, 0xe900, 0x0	# TSS1 descr 0x30
	.word 0x0040, ldt1, 0xe200, 0x0	# LDT1 descr 0x38
end_gdt:
	.fill 128,4,0
init_stack:                          # Will be used as user stack for task0.
	.long init_stack
	.word 0x10

/*************************************/
.align 8
ldt0:	.quad 0x0000000000000000
	.quad 0x00c0fa00000003ff	# 0x0f, base = 0x00000
	.quad 0x00c0f200000003ff	# 0x17

tss0:	.long 0 			/* back link */
	.long krn_stk0, 0x10		/* esp0, ss0 */
	.long 0, 0, 0, 0, 0		/* esp1, ss1, esp2, ss2, cr3 */
	.long 0, 0, 0, 0, 0		/* eip, eflags, eax, ecx, edx */
	.long 0, 0, 0, 0, 0		/* ebx esp, ebp, esi, edi */
	.long 0, 0, 0, 0, 0, 0 		/* es, cs, ss, ds, fs, gs */
	.long LDT0_SEL, 0x8000000	/* ldt, trace bitmap */

	.fill 128,4,0
krn_stk0:
#	.long 0

/************************************/
.align 8
ldt1:	.quad 0x0000000000000000
	.quad 0x00c0fa00000003ff	# 0x0f, base = 0x00000
	.quad 0x00c0f200000003ff	# 0x17

tss1:	.long 0 			/* back link */
	.long krn_stk1, 0x10		/* esp0, ss0 */
	.long 0, 0, 0, 0, 0		/* esp1, ss1, esp2, ss2, cr3 */
	.long task1, 0x200		/* eip, eflags */
	.long 0, 0, 0, 0		/* eax, ecx, edx, ebx */
	.long usr_stk1, 0, 0, 0		/* esp, ebp, esi, edi */
	.long 0x17,0x0f,0x17,0x17,0x17,0x17 /* es, cs, ss, ds, fs, gs */
	.long LDT1_SEL, 0x8000000	/* ldt, trace bitmap */

	.fill 128,4,0
krn_stk1:

/************************************/
task0:
	movl $0x17, %eax
	movw %ax, %ds
	movb $65, %al              /* print 'A' */
	int $0x80
	movl $0xfff, %ecx
1:	loop 1b
	jmp task0 

task1:
	movl $0x17, %eax
	movw %ax, %ds
	movb $66, %al              /* print 'B' */
	int $0x80
	movl $0xfff, %ecx
1:	loop 1b
	jmp task1

	.fill 128,4,0 
usr_stk1:
