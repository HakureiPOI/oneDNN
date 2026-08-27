
/root/onednn-verify/dynval/divzero_probe：     文件格式 elf64-littleriscv


Disassembly of section .plt:

00000000000005b0 <.plt>:
 5b0:	00002397          	auipc	t2,0x2
 5b4:	41c30333          	sub	t1,t1,t3
 5b8:	a003be03          	ld	t3,-1536(t2) # 1fb0 <.got>
 5bc:	fd430313          	addi	t1,t1,-44
 5c0:	a0038293          	addi	t0,t2,-1536
 5c4:	00135313          	srli	t1,t1,0x1
 5c8:	0082b283          	ld	t0,8(t0)
 5cc:	000e0067          	jr	t3

00000000000005d0 <__libc_start_main@plt>:
 5d0:	00002e17          	auipc	t3,0x2
 5d4:	9f0e3e03          	ld	t3,-1552(t3) # 1fc0 <__libc_start_main@GLIBC_2.34>
 5d8:	000e0367          	jalr	t1,t3
 5dc:	00000013          	nop

00000000000005e0 <__printf_chk@plt>:
 5e0:	00002e17          	auipc	t3,0x2
 5e4:	9e8e3e03          	ld	t3,-1560(t3) # 1fc8 <__printf_chk@GLIBC_2.27>
 5e8:	000e0367          	jalr	t1,t3
 5ec:	00000013          	nop

00000000000005f0 <puts@plt>:
 5f0:	00002e17          	auipc	t3,0x2
 5f4:	9e0e3e03          	ld	t3,-1568(t3) # 1fd0 <puts@GLIBC_2.27>
 5f8:	000e0367          	jalr	t1,t3
 5fc:	00000013          	nop

Disassembly of section .text:

0000000000000600 <main>:
 600:	1141                	addi	sp,sp,-16
 602:	e406                	sd	ra,8(sp)
 604:	e022                	sd	s0,0(sp)
 606:	451d                	li	a0,7
 608:	4581                	li	a1,0
 60a:	02b54633          	div	a2,a0,a1
 60e:	00000597          	auipc	a1,0x0
 612:	13258593          	addi	a1,a1,306 # 740 <_IO_stdin_used+0x8>
 616:	4509                	li	a0,2
 618:	fc9ff0ef          	jal	5e0 <__printf_chk@plt>
 61c:	00002717          	auipc	a4,0x2
 620:	9ec73703          	ld	a4,-1556(a4) # 2008 <nthr_v>
 624:	00002797          	auipc	a5,0x2
 628:	9f478793          	addi	a5,a5,-1548 # 2018 <tasks>
 62c:	638c                	ld	a1,0(a5)
 62e:	fff70413          	addi	s0,a4,-1
 632:	6394                	ld	a3,0(a5)
 634:	863a                	mv	a2,a4
 636:	639c                	ld	a5,0(a5)
 638:	4509                	li	a0,2
 63a:	02b44433          	div	s0,s0,a1
 63e:	00000597          	auipc	a1,0x0
 642:	13258593          	addi	a1,a1,306 # 770 <_IO_stdin_used+0x38>
 646:	0405                	addi	s0,s0,1
 648:	8822                	mv	a6,s0
 64a:	f97ff0ef          	jal	5e0 <__printf_chk@plt>
 64e:	86a2                	mv	a3,s0
 650:	4785                	li	a5,1
 652:	4705                	li	a4,1
 654:	4605                	li	a2,1
 656:	00000597          	auipc	a1,0x0
 65a:	15258593          	addi	a1,a1,338 # 7a8 <_IO_stdin_used+0x70>
 65e:	4509                	li	a0,2
 660:	f81ff0ef          	jal	5e0 <__printf_chk@plt>
 664:	00000517          	auipc	a0,0x0
 668:	17c50513          	addi	a0,a0,380 # 7e0 <_IO_stdin_used+0xa8>
 66c:	f85ff0ef          	jal	5f0 <puts@plt>
 670:	60a2                	ld	ra,8(sp)
 672:	4501                	li	a0,0
 674:	6402                	ld	s0,0(sp)
 676:	0141                	addi	sp,sp,16
 678:	8082                	ret
	...

000000000000067c <_start>:
 67c:	022000ef          	jal	69e <load_gp>
 680:	87aa                	mv	a5,a0
 682:	00002517          	auipc	a0,0x2
 686:	96653503          	ld	a0,-1690(a0) # 1fe8 <_GLOBAL_OFFSET_TABLE_+0x10>
 68a:	6582                	ld	a1,0(sp)
 68c:	0030                	addi	a2,sp,8
 68e:	ff017113          	andi	sp,sp,-16
 692:	4681                	li	a3,0
 694:	4701                	li	a4,0
 696:	880a                	mv	a6,sp
 698:	f39ff0ef          	jal	5d0 <__libc_start_main@plt>
 69c:	9002                	ebreak

000000000000069e <load_gp>:
 69e:	00002197          	auipc	gp,0x2
 6a2:	16218193          	addi	gp,gp,354 # 2800 <__global_pointer$>
 6a6:	8082                	ret
	...

00000000000006aa <deregister_tm_clones>:
 6aa:	00002797          	auipc	a5,0x2
 6ae:	96678793          	addi	a5,a5,-1690 # 2010 <__TMC_END__>
 6b2:	00002517          	auipc	a0,0x2
 6b6:	95e50513          	addi	a0,a0,-1698 # 2010 <__TMC_END__>
 6ba:	00a78863          	beq	a5,a0,6ca <deregister_tm_clones+0x20>
 6be:	00002797          	auipc	a5,0x2
 6c2:	9227b783          	ld	a5,-1758(a5) # 1fe0 <_ITM_deregisterTMCloneTable@Base>
 6c6:	c391                	beqz	a5,6ca <deregister_tm_clones+0x20>
 6c8:	8782                	jr	a5
 6ca:	8082                	ret

00000000000006cc <register_tm_clones>:
 6cc:	00002517          	auipc	a0,0x2
 6d0:	94450513          	addi	a0,a0,-1724 # 2010 <__TMC_END__>
 6d4:	00002597          	auipc	a1,0x2
 6d8:	93c58593          	addi	a1,a1,-1732 # 2010 <__TMC_END__>
 6dc:	8d89                	sub	a1,a1,a0
 6de:	4035d793          	srai	a5,a1,0x3
 6e2:	91fd                	srli	a1,a1,0x3f
 6e4:	95be                	add	a1,a1,a5
 6e6:	8585                	srai	a1,a1,0x1
 6e8:	c599                	beqz	a1,6f6 <register_tm_clones+0x2a>
 6ea:	00002797          	auipc	a5,0x2
 6ee:	90e7b783          	ld	a5,-1778(a5) # 1ff8 <_ITM_registerTMCloneTable@Base>
 6f2:	c391                	beqz	a5,6f6 <register_tm_clones+0x2a>
 6f4:	8782                	jr	a5
 6f6:	8082                	ret

00000000000006f8 <__do_global_dtors_aux>:
 6f8:	1141                	addi	sp,sp,-16
 6fa:	e022                	sd	s0,0(sp)
 6fc:	00002417          	auipc	s0,0x2
 700:	91440413          	addi	s0,s0,-1772 # 2010 <__TMC_END__>
 704:	00044783          	lbu	a5,0(s0)
 708:	e406                	sd	ra,8(sp)
 70a:	e385                	bnez	a5,72a <__do_global_dtors_aux+0x32>
 70c:	00002797          	auipc	a5,0x2
 710:	8e47b783          	ld	a5,-1820(a5) # 1ff0 <__cxa_finalize@GLIBC_2.27>
 714:	c791                	beqz	a5,720 <__do_global_dtors_aux+0x28>
 716:	00002517          	auipc	a0,0x2
 71a:	8ea53503          	ld	a0,-1814(a0) # 2000 <__dso_handle>
 71e:	9782                	jalr	a5
 720:	f8bff0ef          	jal	6aa <deregister_tm_clones>
 724:	4785                	li	a5,1
 726:	00f40023          	sb	a5,0(s0)
 72a:	60a2                	ld	ra,8(sp)
 72c:	6402                	ld	s0,0(sp)
 72e:	0141                	addi	sp,sp,16
 730:	8082                	ret

0000000000000732 <frame_dummy>:
 732:	bf69                	j	6cc <register_tm_clones>
