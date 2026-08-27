
/root/onednn-verify/dynval/vta_probe：     文件格式 elf64-littleriscv


Disassembly of section .plt:

0000000000000640 <.plt>:
 640:	00002397          	auipc	t2,0x2
 644:	41c30333          	sub	t1,t1,t3
 648:	9683be03          	ld	t3,-1688(t2) # 1fa8 <.got>
 64c:	fd430313          	addi	t1,t1,-44
 650:	96838293          	addi	t0,t2,-1688
 654:	00135313          	srli	t1,t1,0x1
 658:	0082b283          	ld	t0,8(t0)
 65c:	000e0067          	jr	t3

0000000000000660 <__libc_start_main@plt>:
 660:	00002e17          	auipc	t3,0x2
 664:	958e3e03          	ld	t3,-1704(t3) # 1fb8 <__libc_start_main@GLIBC_2.34>
 668:	000e0367          	jalr	t1,t3
 66c:	00000013          	nop

0000000000000670 <__printf_chk@plt>:
 670:	00002e17          	auipc	t3,0x2
 674:	950e3e03          	ld	t3,-1712(t3) # 1fc0 <__printf_chk@GLIBC_2.27>
 678:	000e0367          	jalr	t1,t3
 67c:	00000013          	nop

0000000000000680 <__stack_chk_fail@plt>:
 680:	00002e17          	auipc	t3,0x2
 684:	948e3e03          	ld	t3,-1720(t3) # 1fc8 <__stack_chk_fail@GLIBC_2.27>
 688:	000e0367          	jalr	t1,t3
 68c:	00000013          	nop

Disassembly of section .text:

0000000000000690 <_start>:
 690:	022000ef          	jal	6b2 <load_gp>
 694:	87aa                	mv	a5,a0
 696:	00002517          	auipc	a0,0x2
 69a:	95253503          	ld	a0,-1710(a0) # 1fe8 <_GLOBAL_OFFSET_TABLE_+0x18>
 69e:	6582                	ld	a1,0(sp)
 6a0:	0030                	addi	a2,sp,8
 6a2:	ff017113          	andi	sp,sp,-16
 6a6:	4681                	li	a3,0
 6a8:	4701                	li	a4,0
 6aa:	880a                	mv	a6,sp
 6ac:	fb5ff0ef          	jal	660 <__libc_start_main@plt>
 6b0:	9002                	ebreak

00000000000006b2 <load_gp>:
 6b2:	00002197          	auipc	gp,0x2
 6b6:	14e18193          	addi	gp,gp,334 # 2800 <__global_pointer$>
 6ba:	8082                	ret
	...

00000000000006be <deregister_tm_clones>:
 6be:	00002797          	auipc	a5,0x2
 6c2:	94a78793          	addi	a5,a5,-1718 # 2008 <__TMC_END__>
 6c6:	00002517          	auipc	a0,0x2
 6ca:	94250513          	addi	a0,a0,-1726 # 2008 <__TMC_END__>
 6ce:	00a78863          	beq	a5,a0,6de <deregister_tm_clones+0x20>
 6d2:	00002797          	auipc	a5,0x2
 6d6:	9067b783          	ld	a5,-1786(a5) # 1fd8 <_ITM_deregisterTMCloneTable@Base>
 6da:	c391                	beqz	a5,6de <deregister_tm_clones+0x20>
 6dc:	8782                	jr	a5
 6de:	8082                	ret

00000000000006e0 <register_tm_clones>:
 6e0:	00002517          	auipc	a0,0x2
 6e4:	92850513          	addi	a0,a0,-1752 # 2008 <__TMC_END__>
 6e8:	00002597          	auipc	a1,0x2
 6ec:	92058593          	addi	a1,a1,-1760 # 2008 <__TMC_END__>
 6f0:	8d89                	sub	a1,a1,a0
 6f2:	4035d793          	srai	a5,a1,0x3
 6f6:	91fd                	srli	a1,a1,0x3f
 6f8:	95be                	add	a1,a1,a5
 6fa:	8585                	srai	a1,a1,0x1
 6fc:	c599                	beqz	a1,70a <register_tm_clones+0x2a>
 6fe:	00002797          	auipc	a5,0x2
 702:	8fa7b783          	ld	a5,-1798(a5) # 1ff8 <_ITM_registerTMCloneTable@Base>
 706:	c391                	beqz	a5,70a <register_tm_clones+0x2a>
 708:	8782                	jr	a5
 70a:	8082                	ret

000000000000070c <__do_global_dtors_aux>:
 70c:	1141                	addi	sp,sp,-16
 70e:	e022                	sd	s0,0(sp)
 710:	00002417          	auipc	s0,0x2
 714:	8f840413          	addi	s0,s0,-1800 # 2008 <__TMC_END__>
 718:	00044783          	lbu	a5,0(s0)
 71c:	e406                	sd	ra,8(sp)
 71e:	e385                	bnez	a5,73e <__do_global_dtors_aux+0x32>
 720:	00002797          	auipc	a5,0x2
 724:	8d07b783          	ld	a5,-1840(a5) # 1ff0 <__cxa_finalize@GLIBC_2.27>
 728:	c791                	beqz	a5,734 <__do_global_dtors_aux+0x28>
 72a:	00002517          	auipc	a0,0x2
 72e:	8d653503          	ld	a0,-1834(a0) # 2000 <__dso_handle>
 732:	9782                	jalr	a5
 734:	f8bff0ef          	jal	6be <deregister_tm_clones>
 738:	4785                	li	a5,1
 73a:	00f40023          	sb	a5,0(s0)
 73e:	60a2                	ld	ra,8(sp)
 740:	6402                	ld	s0,0(sp)
 742:	0141                	addi	sp,sp,16
 744:	8082                	ret

0000000000000746 <frame_dummy>:
 746:	bf69                	j	6e0 <register_tm_clones>

0000000000000748 <main>:
 748:	de010113          	addi	sp,sp,-544
 74c:	20113c23          	sd	ra,536(sp)
 750:	00002797          	auipc	a5,0x2
 754:	8907b783          	ld	a5,-1904(a5) # 1fe0 <__stack_chk_guard@GLIBC_2.27>
 758:	6398                	ld	a4,0(a5)
 75a:	20e13423          	sd	a4,520(sp)
 75e:	4701                	li	a4,0
 760:	0038                	addi	a4,sp,8
 762:	4781                	li	a5,0
 764:	00000697          	auipc	a3,0x0
 768:	1086a707          	flw	fa4,264(a3) # 86c <_IO_stdin_used+0x4>
 76c:	04000693          	li	a3,64
 770:	d007f7d3          	fcvt.s.w	fa5,a5
 774:	00e7f7d3          	fadd.s	fa5,fa5,fa4
 778:	00f72027          	fsw	fa5,0(a4)
 77c:	2785                	addiw	a5,a5,1
 77e:	0711                	addi	a4,a4,4
 780:	fed798e3          	bne	a5,a3,770 <main+0x28>
 784:	0238                	addi	a4,sp,264
 786:	003c                	addi	a5,sp,8
 788:	0d3072d7          	vsetvli	t0,zero,e32,m8,ta,ma
 78c:	0207e407          	vle32.v	v8,(a5)
 790:	4305                	li	t1,1
 792:	0d3372d7          	vsetvli	t0,t1,e32,m8,ta,ma
 796:	5e003857          	vmv.v.i	v16,0
 79a:	02881457          	vfadd.vv	v8,v8,v16
 79e:	0d3072d7          	vsetvli	t0,zero,e32,m8,ta,ma
 7a2:	02076427          	vse32.v	v8,(a4)
 7a6:	0278                	addi	a4,sp,268
 7a8:	006c                	addi	a1,sp,12
 7aa:	20810893          	addi	a7,sp,520
 7ae:	4681                	li	a3,0
 7b0:	4601                	li	a2,0
 7b2:	587d                	li	a6,-1
 7b4:	a801                	j	7c4 <main+0x7c>
 7b6:	2781                	sext.w	a5,a5
 7b8:	03078063          	beq	a5,a6,7d8 <main+0x90>
 7bc:	0711                	addi	a4,a4,4
 7be:	0591                	addi	a1,a1,4
 7c0:	01170e63          	beq	a4,a7,7dc <main+0x94>
 7c4:	431c                	lw	a5,0(a4)
 7c6:	0005a787          	flw	fa5,0(a1)
 7ca:	f0078753          	fmv.w.x	fa4,a5
 7ce:	a0f72553          	feq.s	a0,fa4,fa5
 7d2:	f175                	bnez	a0,7b6 <main+0x6e>
 7d4:	2605                	addiw	a2,a2,1
 7d6:	b7c5                	j	7b6 <main+0x6e>
 7d8:	2685                	addiw	a3,a3,1
 7da:	b7cd                	j	7bc <main+0x74>
 7dc:	00000597          	auipc	a1,0x0
 7e0:	09458593          	addi	a1,a1,148 # 870 <_IO_stdin_used+0x8>
 7e4:	4509                	li	a0,2
 7e6:	e8bff0ef          	jal	670 <__printf_chk@plt>
 7ea:	10412787          	flw	fa5,260(sp)
 7ee:	420787d3          	fcvt.d.s	fa5,fa5
 7f2:	e20788d3          	fmv.x.d	a7,fa5
 7f6:	08812787          	flw	fa5,136(sp)
 7fa:	420787d3          	fcvt.d.s	fa5,fa5
 7fe:	e2078853          	fmv.x.d	a6,fa5
 802:	00c12787          	flw	fa5,12(sp)
 806:	420787d3          	fcvt.d.s	fa5,fa5
 80a:	e20787d3          	fmv.x.d	a5,fa5
 80e:	20412787          	flw	fa5,516(sp)
 812:	420787d3          	fcvt.d.s	fa5,fa5
 816:	e2078753          	fmv.x.d	a4,fa5
 81a:	18812787          	flw	fa5,392(sp)
 81e:	420787d3          	fcvt.d.s	fa5,fa5
 822:	e20786d3          	fmv.x.d	a3,fa5
 826:	10c12787          	flw	fa5,268(sp)
 82a:	420787d3          	fcvt.d.s	fa5,fa5
 82e:	e2078653          	fmv.x.d	a2,fa5
 832:	00000597          	auipc	a1,0x0
 836:	07658593          	addi	a1,a1,118 # 8a8 <_IO_stdin_used+0x40>
 83a:	4509                	li	a0,2
 83c:	e35ff0ef          	jal	670 <__printf_chk@plt>
 840:	00001797          	auipc	a5,0x1
 844:	7a07b783          	ld	a5,1952(a5) # 1fe0 <__stack_chk_guard@GLIBC_2.27>
 848:	20813703          	ld	a4,520(sp)
 84c:	639c                	ld	a5,0(a5)
 84e:	8fb9                	xor	a5,a5,a4
 850:	4701                	li	a4,0
 852:	e799                	bnez	a5,860 <main+0x118>
 854:	4501                	li	a0,0
 856:	21813083          	ld	ra,536(sp)
 85a:	22010113          	addi	sp,sp,544
 85e:	8082                	ret
 860:	e21ff0ef          	jal	680 <__stack_chk_fail@plt>
