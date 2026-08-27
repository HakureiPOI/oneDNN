
zvfbfwma_probe：     文件格式 elf64-littleriscv


Disassembly of section .plt:

0000000000000770 <.plt>:
 770:	00002397          	auipc	t2,0x2
 774:	41c30333          	sub	t1,t1,t3
 778:	8103be03          	ld	t3,-2032(t2) # 1f80 <.got>
 77c:	fd430313          	addi	t1,t1,-44
 780:	81038293          	addi	t0,t2,-2032
 784:	00135313          	srli	t1,t1,0x1
 788:	0082b283          	ld	t0,8(t0)
 78c:	000e0067          	jr	t3

0000000000000790 <__libc_start_main@plt>:
 790:	00002e17          	auipc	t3,0x2
 794:	800e3e03          	ld	t3,-2048(t3) # 1f90 <__libc_start_main@GLIBC_2.34>
 798:	000e0367          	jalr	t1,t3
 79c:	00000013          	nop

00000000000007a0 <__sigsetjmp@plt>:
 7a0:	00001e17          	auipc	t3,0x1
 7a4:	7f8e3e03          	ld	t3,2040(t3) # 1f98 <__sigsetjmp@GLIBC_2.27>
 7a8:	000e0367          	jalr	t1,t3
 7ac:	00000013          	nop

00000000000007b0 <__printf_chk@plt>:
 7b0:	00001e17          	auipc	t3,0x1
 7b4:	7f0e3e03          	ld	t3,2032(t3) # 1fa0 <__printf_chk@GLIBC_2.27>
 7b8:	000e0367          	jalr	t1,t3
 7bc:	00000013          	nop

00000000000007c0 <__stack_chk_fail@plt>:
 7c0:	00001e17          	auipc	t3,0x1
 7c4:	7e8e3e03          	ld	t3,2024(t3) # 1fa8 <__stack_chk_fail@GLIBC_2.27>
 7c8:	000e0367          	jalr	t1,t3
 7cc:	00000013          	nop

00000000000007d0 <__longjmp_chk@plt>:
 7d0:	00001e17          	auipc	t3,0x1
 7d4:	7e0e3e03          	ld	t3,2016(t3) # 1fb0 <__longjmp_chk@GLIBC_2.27>
 7d8:	000e0367          	jalr	t1,t3
 7dc:	00000013          	nop

00000000000007e0 <puts@plt>:
 7e0:	00001e17          	auipc	t3,0x1
 7e4:	7d8e3e03          	ld	t3,2008(t3) # 1fb8 <puts@GLIBC_2.27>
 7e8:	000e0367          	jalr	t1,t3
 7ec:	00000013          	nop

00000000000007f0 <sigaction@plt>:
 7f0:	00001e17          	auipc	t3,0x1
 7f4:	7d0e3e03          	ld	t3,2000(t3) # 1fc0 <sigaction@GLIBC_2.27>
 7f8:	000e0367          	jalr	t1,t3
 7fc:	00000013          	nop

0000000000000800 <sigemptyset@plt>:
 800:	00001e17          	auipc	t3,0x1
 804:	7c8e3e03          	ld	t3,1992(t3) # 1fc8 <sigemptyset@GLIBC_2.27>
 808:	000e0367          	jalr	t1,t3
 80c:	00000013          	nop

Disassembly of section .text:

0000000000000810 <main>:
 810:	714d                	addi	sp,sp,-336
 812:	00001797          	auipc	a5,0x1
 816:	7ce7b783          	ld	a5,1998(a5) # 1fe0 <__stack_chk_guard@GLIBC_2.27>
 81a:	0808                	addi	a0,sp,16
 81c:	6398                	ld	a4,0(a5)
 81e:	fe3a                	sd	a4,312(sp)
 820:	4701                	li	a4,0
 822:	00000797          	auipc	a5,0x0
 826:	17678793          	addi	a5,a5,374 # 998 <sigill_handler>
 82a:	e686                	sd	ra,328(sp)
 82c:	e43e                	sd	a5,8(sp)
 82e:	fd3ff0ef          	jal	800 <sigemptyset@plt>
 832:	1110                	addi	a2,sp,160
 834:	002c                	addi	a1,sp,8
 836:	c902                	sw	zero,144(sp)
 838:	4511                	li	a0,4
 83a:	fb7ff0ef          	jal	7f0 <sigaction@plt>
 83e:	c505                	beqz	a0,866 <main+0x56>
 840:	00000517          	auipc	a0,0x0
 844:	1b050513          	addi	a0,a0,432 # 9f0 <_IO_stdin_used+0x38>
 848:	f99ff0ef          	jal	7e0 <puts@plt>
 84c:	4509                	li	a0,2
 84e:	00001797          	auipc	a5,0x1
 852:	7927b783          	ld	a5,1938(a5) # 1fe0 <__stack_chk_guard@GLIBC_2.27>
 856:	7772                	ld	a4,312(sp)
 858:	639c                	ld	a5,0(a5)
 85a:	8fb9                	xor	a5,a5,a4
 85c:	4701                	li	a4,0
 85e:	efb5                	bnez	a5,8da <main+0xca>
 860:	60b6                	ld	ra,328(sp)
 862:	6171                	addi	sp,sp,336
 864:	8082                	ret
 866:	4585                	li	a1,1
 868:	00001517          	auipc	a0,0x1
 86c:	7b050513          	addi	a0,a0,1968 # 2018 <probe_jmp>
 870:	f31ff0ef          	jal	7a0 <__sigsetjmp@plt>
 874:	ed21                	bnez	a0,8cc <main+0xbc>
 876:	cc807057          	.word	0xcc807057
 87a:	ee655157          	.word	0xee655157
 87e:	00000517          	auipc	a0,0x0
 882:	18a50513          	addi	a0,a0,394 # a08 <_IO_stdin_used+0x50>
 886:	f5bff0ef          	jal	7e0 <puts@plt>
 88a:	110c                	addi	a1,sp,160
 88c:	4601                	li	a2,0
 88e:	4511                	li	a0,4
 890:	f61ff0ef          	jal	7f0 <sigaction@plt>
 894:	00001797          	auipc	a5,0x1
 898:	77c7a783          	lw	a5,1916(a5) # 2010 <trapped>
 89c:	00000617          	auipc	a2,0x0
 8a0:	12460613          	addi	a2,a2,292 # 9c0 <_IO_stdin_used+0x8>
 8a4:	cf99                	beqz	a5,8c2 <main+0xb2>
 8a6:	00000597          	auipc	a1,0x0
 8aa:	18a58593          	addi	a1,a1,394 # a30 <_IO_stdin_used+0x78>
 8ae:	4509                	li	a0,2
 8b0:	f01ff0ef          	jal	7b0 <__printf_chk@plt>
 8b4:	00001517          	auipc	a0,0x1
 8b8:	75c52503          	lw	a0,1884(a0) # 2010 <trapped>
 8bc:	00a03533          	snez	a0,a0
 8c0:	b779                	j	84e <main+0x3e>
 8c2:	00000617          	auipc	a2,0x0
 8c6:	11e60613          	addi	a2,a2,286 # 9e0 <_IO_stdin_used+0x28>
 8ca:	bff1                	j	8a6 <main+0x96>
 8cc:	00000517          	auipc	a0,0x0
 8d0:	15450513          	addi	a0,a0,340 # a20 <_IO_stdin_used+0x68>
 8d4:	f0dff0ef          	jal	7e0 <puts@plt>
 8d8:	bf4d                	j	88a <main+0x7a>
 8da:	ee7ff0ef          	jal	7c0 <__stack_chk_fail@plt>
	...

00000000000008e0 <_start>:
 8e0:	022000ef          	jal	902 <load_gp>
 8e4:	87aa                	mv	a5,a0
 8e6:	00001517          	auipc	a0,0x1
 8ea:	70253503          	ld	a0,1794(a0) # 1fe8 <_GLOBAL_OFFSET_TABLE_+0x18>
 8ee:	6582                	ld	a1,0(sp)
 8f0:	0030                	addi	a2,sp,8
 8f2:	ff017113          	andi	sp,sp,-16
 8f6:	4681                	li	a3,0
 8f8:	4701                	li	a4,0
 8fa:	880a                	mv	a6,sp
 8fc:	e95ff0ef          	jal	790 <__libc_start_main@plt>
 900:	9002                	ebreak

0000000000000902 <load_gp>:
 902:	00002197          	auipc	gp,0x2
 906:	efe18193          	addi	gp,gp,-258 # 2800 <__global_pointer$>
 90a:	8082                	ret
	...

000000000000090e <deregister_tm_clones>:
 90e:	00001797          	auipc	a5,0x1
 912:	6fa78793          	addi	a5,a5,1786 # 2008 <__TMC_END__>
 916:	00001517          	auipc	a0,0x1
 91a:	6f250513          	addi	a0,a0,1778 # 2008 <__TMC_END__>
 91e:	00a78863          	beq	a5,a0,92e <deregister_tm_clones+0x20>
 922:	00001797          	auipc	a5,0x1
 926:	6b67b783          	ld	a5,1718(a5) # 1fd8 <_ITM_deregisterTMCloneTable@Base>
 92a:	c391                	beqz	a5,92e <deregister_tm_clones+0x20>
 92c:	8782                	jr	a5
 92e:	8082                	ret

0000000000000930 <register_tm_clones>:
 930:	00001517          	auipc	a0,0x1
 934:	6d850513          	addi	a0,a0,1752 # 2008 <__TMC_END__>
 938:	00001597          	auipc	a1,0x1
 93c:	6d058593          	addi	a1,a1,1744 # 2008 <__TMC_END__>
 940:	8d89                	sub	a1,a1,a0
 942:	4035d793          	srai	a5,a1,0x3
 946:	91fd                	srli	a1,a1,0x3f
 948:	95be                	add	a1,a1,a5
 94a:	8585                	srai	a1,a1,0x1
 94c:	c599                	beqz	a1,95a <register_tm_clones+0x2a>
 94e:	00001797          	auipc	a5,0x1
 952:	6aa7b783          	ld	a5,1706(a5) # 1ff8 <_ITM_registerTMCloneTable@Base>
 956:	c391                	beqz	a5,95a <register_tm_clones+0x2a>
 958:	8782                	jr	a5
 95a:	8082                	ret

000000000000095c <__do_global_dtors_aux>:
 95c:	1141                	addi	sp,sp,-16
 95e:	e022                	sd	s0,0(sp)
 960:	00001417          	auipc	s0,0x1
 964:	6a840413          	addi	s0,s0,1704 # 2008 <__TMC_END__>
 968:	00044783          	lbu	a5,0(s0)
 96c:	e406                	sd	ra,8(sp)
 96e:	e385                	bnez	a5,98e <__do_global_dtors_aux+0x32>
 970:	00001797          	auipc	a5,0x1
 974:	6807b783          	ld	a5,1664(a5) # 1ff0 <__cxa_finalize@GLIBC_2.27>
 978:	c791                	beqz	a5,984 <__do_global_dtors_aux+0x28>
 97a:	00001517          	auipc	a0,0x1
 97e:	68653503          	ld	a0,1670(a0) # 2000 <__dso_handle>
 982:	9782                	jalr	a5
 984:	f8bff0ef          	jal	90e <deregister_tm_clones>
 988:	4785                	li	a5,1
 98a:	00f40023          	sb	a5,0(s0)
 98e:	60a2                	ld	ra,8(sp)
 990:	6402                	ld	s0,0(sp)
 992:	0141                	addi	sp,sp,16
 994:	8082                	ret

0000000000000996 <frame_dummy>:
 996:	bf69                	j	930 <register_tm_clones>

0000000000000998 <sigill_handler>:
 998:	1141                	addi	sp,sp,-16
 99a:	4785                	li	a5,1
 99c:	e406                	sd	ra,8(sp)
 99e:	00001717          	auipc	a4,0x1
 9a2:	66f72923          	sw	a5,1650(a4) # 2010 <trapped>
 9a6:	4585                	li	a1,1
 9a8:	00001517          	auipc	a0,0x1
 9ac:	67050513          	addi	a0,a0,1648 # 2018 <probe_jmp>
 9b0:	e21ff0ef          	jal	7d0 <__longjmp_chk@plt>
