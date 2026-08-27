# Disassembly of jit_uni_shuffle_t::execute (release libdnnl.so.3.14)
# command: objdump -d --start-address=0x609372 --stop-address=0x609a7c \
#            ~/onednn-verify/build-rel/src/libdnnl.so.3.14
# symbol: _ZNK4dnnl4impl3cpu4rv6417jit_uni_shuffle_t7executeERKNS0_10exec_ctx_tE @ 0x609372
# next symbol: precompute_offsets @ 0x609a7c
# purpose: RV64-004 release mechanism — locate the div sequence for the
#   zero-task path: div_up(nthr, tasks) with tasks==0, then div_up(sp, inner)


/root/onednn-verify/build-rel/src/libdnnl.so.3.14：     文件格式 elf64-littleriscv


Disassembly of section .text:

0000000000609372 <_ZNK4dnnl4impl3cpu4rv6417jit_uni_shuffle_t7executeERKNS0_10exec_ctx_tE>:
  609372:	651c                	ld	a5,8(a0)
  609374:	6685                	lui	a3,0x1
  609376:	7165                	addi	sp,sp,-400
  609378:	e322                	sd	s0,384(sp)
  60937a:	842e                	mv	s0,a1
  60937c:	97b6                	add	a5,a5,a3
  60937e:	fea6                	sd	s1,376(sp)
  609380:	bcc7a783          	lw	a5,-1076(a5)
  609384:	eed6                	sd	s5,344(sp)
  609386:	e706                	sd	ra,392(sp)
  609388:	00134a97          	auipc	s5,0x134
  60938c:	850aba83          	ld	s5,-1968(s5) # 73cbd8 <__stack_chk_guard@GLIBC_2.27>
  609390:	faca                	sd	s2,368(sp)
  609392:	000ab703          	ld	a4,0(s5)
  609396:	fe3a                	sd	a4,312(sp)
  609398:	4701                	li	a4,0
  60939a:	f6ce                	sd	s3,360(sp)
  60939c:	fdf7f793          	andi	a5,a5,-33
  6093a0:	f2d2                	sd	s4,352(sp)
  6093a2:	84aa                	mv	s1,a0
  6093a4:	eada                	sd	s6,336(sp)
  6093a6:	04000713          	li	a4,64
  6093aa:	e6de                	sd	s7,328(sp)
  6093ac:	e2e2                	sd	s8,320(sp)
  6093ae:	28e78063          	beq	a5,a4,60962e <_ZNK4dnnl4impl3cpu4rv6417jit_uni_shuffle_t7executeERKNS0_10exec_ctx_tE+0x2bc>
  6093b2:	09100593          	li	a1,145
  6093b6:	08100913          	li	s2,129
  6093ba:	8522                	mv	a0,s0
  6093bc:	4701                	li	a4,0
  6093be:	4681                	li	a3,0
  6093c0:	4601                	li	a2,0
  6093c2:	ffb89097          	auipc	ra,0xffb89
  6093c6:	ac0080e7          	jalr	-1344(ra) # 191e82 <_ZNK4dnnl4impl10exec_ctx_t8host_ptrEibP13dnnl_status_ti>
  6093ca:	8a2a                	mv	s4,a0
  6093cc:	85ca                	mv	a1,s2
  6093ce:	8522                	mv	a0,s0
  6093d0:	4701                	li	a4,0
  6093d2:	4681                	li	a3,0
  6093d4:	4601                	li	a2,0
  6093d6:	ffb89097          	auipc	ra,0xffb89
  6093da:	aac080e7          	jalr	-1364(ra) # 191e82 <_ZNK4dnnl4impl10exec_ctx_t8host_ptrEibP13dnnl_status_ti>
  6093de:	649c                	ld	a5,8(s1)
  6093e0:	6709                	lui	a4,0x2
  6093e2:	89aa                	mv	s3,a0
  6093e4:	97ba                	add	a5,a5,a4
  6093e6:	8087b703          	ld	a4,-2040(a5)
  6093ea:	8007bb03          	ld	s6,-2048(a5)
  6093ee:	8107b583          	ld	a1,-2032(a5)
  6093f2:	8187b603          	ld	a2,-2024(a5)
  6093f6:	fc3a                	sd	a4,56(sp)
  6093f8:	8207b683          	ld	a3,-2016(a5)
  6093fc:	f85a                	sd	s6,48(sp)
  6093fe:	8287b703          	ld	a4,-2008(a5)
  609402:	e0ae                	sd	a1,64(sp)
  609404:	8307bb83          	ld	s7,-2000(a5)
  609408:	e4b2                	sd	a2,72(sp)
  60940a:	e8b6                	sd	a3,80(sp)
  60940c:	ecba                	sd	a4,88(sp)
  60940e:	f0de                	sd	s7,96(sp)
  609410:	ffa45097          	auipc	ra,0xffa45
  609414:	d60080e7          	jalr	-672(ra) # 4e170 <omp_in_parallel@plt>
  609418:	1c050363          	beqz	a0,6095de <_ZNK4dnnl4impl3cpu4rv6417jit_uni_shuffle_t7executeERKNS0_10exec_ctx_tE+0x26c>
  60941c:	037b0933          	mul	s2,s6,s7
  609420:	6406                	ld	s0,64(sp)
  609422:	4c05                	li	s8,1
  609424:	19204c63          	bgtz	s2,6095bc <_ZNK4dnnl4impl3cpu4rv6417jit_uni_shuffle_t7executeERKNS0_10exec_ctx_tE+0x24a>
  609428:	24805e63          	blez	s0,609684 <_ZNK4dnnl4impl3cpu4rv6417jit_uni_shuffle_t7executeERKNS0_10exec_ctx_tE+0x312>
  60942c:	147d                	addi	s0,s0,-1
  60942e:	03844c33          	div	s8,s0,s8
  609432:	0c05                	addi	s8,s8,1
  609434:	19804a63          	bgtz	s8,6095c8 <_ZNK4dnnl4impl3cpu4rv6417jit_uni_shuffle_t7executeERKNS0_10exec_ctx_tE+0x256>
  609438:	4c05                	li	s8,1
  60943a:	03844433          	div	s0,s0,s8
  60943e:	0405                	addi	s0,s0,1
  609440:	77c2                	ld	a5,48(sp)
  609442:	e182                	sd	zero,192(sp)
  609444:	e582                	sd	zero,200(sp)
  609446:	05800513          	li	a0,88
  60944a:	e982                	sd	zero,208(sp)
  60944c:	f4be                	sd	a5,104(sp)
  60944e:	77e2                	ld	a5,56(sp)
  609450:	ed82                	sd	zero,216(sp)
  609452:	f8be                	sd	a5,112(sp)
  609454:	6786                	ld	a5,64(sp)
  609456:	fcbe                	sd	a5,120(sp)
  609458:	67a6                	ld	a5,72(sp)
  60945a:	e13e                	sd	a5,128(sp)
  60945c:	67c6                	ld	a5,80(sp)
  60945e:	e53e                	sd	a5,136(sp)
  609460:	67e6                	ld	a5,88(sp)
  609462:	e93e                	sd	a5,144(sp)
  609464:	7786                	ld	a5,96(sp)
  609466:	ed3e                	sd	a5,152(sp)
  609468:	ffa45097          	auipc	ra,0xffa45
  60946c:	028080e7          	jalr	40(ra) # 4e490 <_Znwm@plt>
  609470:	7726                	ld	a4,104(sp)
  609472:	fffff797          	auipc	a5,0xfffff
  609476:	63a78793          	addi	a5,a5,1594 # 608aac <_ZNSt17_Function_handlerIFvlllEZNK4dnnl4impl3cpu4rv6417jit_uni_shuffle_t7executeERKNS2_10exec_ctx_tEEUllllE_E9_M_invokeERKSt9_Any_dataOlSE_SE_>
  60947a:	e924                	sd	s1,80(a0)
  60947c:	03240933          	mul	s2,s0,s2
  609480:	edbe                	sd	a5,216(sp)
  609482:	00000797          	auipc	a5,0x0
  609486:	8c078793          	addi	a5,a5,-1856 # 608d42 <_ZNSt17_Function_handlerIFvlllEZNK4dnnl4impl3cpu4rv6417jit_uni_shuffle_t7executeERKNS2_10exec_ctx_tEEUllllE_E10_M_managerERSt9_Any_dataRKSB_St18_Manager_operation>
  60948a:	e118                	sd	a4,0(a0)
  60948c:	7746                	ld	a4,112(sp)
  60948e:	03853c23          	sd	s8,56(a0)
  609492:	4485                	li	s1,1
  609494:	05453023          	sd	s4,64(a0)
  609498:	e518                	sd	a4,8(a0)
  60949a:	7766                	ld	a4,120(sp)
  60949c:	05353423          	sd	s3,72(a0)
  6094a0:	e1aa                	sd	a0,192(sp)
  6094a2:	e918                	sd	a4,16(a0)
  6094a4:	670a                	ld	a4,128(sp)
  6094a6:	e9be                	sd	a5,208(sp)
  6094a8:	ed18                	sd	a4,24(a0)
  6094aa:	672a                	ld	a4,136(sp)
  6094ac:	f118                	sd	a4,32(a0)
  6094ae:	674a                	ld	a4,144(sp)
  6094b0:	f518                	sd	a4,40(a0)
  6094b2:	676a                	ld	a4,152(sp)
  6094b4:	f918                	sd	a4,48(a0)
  6094b6:	ffa45097          	auipc	ra,0xffa45
  6094ba:	cba080e7          	jalr	-838(ra) # 4e170 <omp_in_parallel@plt>
  6094be:	14050463          	beqz	a0,609606 <_ZNK4dnnl4impl3cpu4rv6417jit_uni_shuffle_t7executeERKNS0_10exec_ctx_tE+0x294>
  6094c2:	4785                	li	a5,1
  6094c4:	10f91663          	bne	s2,a5,6095d0 <_ZNK4dnnl4impl3cpu4rv6417jit_uni_shuffle_t7executeERKNS0_10exec_ctx_tE+0x25e>
  6094c8:	4485                	li	s1,1
  6094ca:	67ce                	ld	a5,208(sp)
  6094cc:	e25a                	sd	s6,256(sp)
  6094ce:	e65e                	sd	s7,264(sp)
  6094d0:	ea22                	sd	s0,272(sp)
  6094d2:	ee02                	sd	zero,280(sp)
  6094d4:	f202                	sd	zero,288(sp)
  6094d6:	f602                	sd	zero,296(sp)
  6094d8:	fa02                	sd	zero,304(sp)
  6094da:	cb91                	beqz	a5,6094ee <_ZNK4dnnl4impl3cpu4rv6417jit_uni_shuffle_t7executeERKNS0_10exec_ctx_tE+0x17c>
  6094dc:	0a20                	addi	s0,sp,280
  6094de:	018c                	addi	a1,sp,192
  6094e0:	8522                	mv	a0,s0
  6094e2:	4609                	li	a2,2
  6094e4:	9782                	jalr	a5
  6094e6:	67ee                	ld	a5,216(sp)
  6094e8:	fa3e                	sd	a5,304(sp)
  6094ea:	67ce                	ld	a5,208(sp)
  6094ec:	f63e                	sd	a5,296(sp)
  6094ee:	f182                	sd	zero,224(sp)
  6094f0:	03800513          	li	a0,56
  6094f4:	f582                	sd	zero,232(sp)
  6094f6:	f982                	sd	zero,240(sp)
  6094f8:	fd82                	sd	zero,248(sp)
  6094fa:	ffa45097          	auipc	ra,0xffa45
  6094fe:	f96080e7          	jalr	-106(ra) # 4e490 <_Znwm@plt>
  609502:	6732                	ld	a4,264(sp)
  609504:	00053c23          	sd	zero,24(a0)
  609508:	77b2                	ld	a5,296(sp)
  60950a:	02053023          	sd	zero,32(a0)
  60950e:	02053423          	sd	zero,40(a0)
  609512:	842a                	mv	s0,a0
  609514:	e518                	sd	a4,8(a0)
  609516:	6752                	ld	a4,272(sp)
  609518:	02053823          	sd	zero,48(a0)
  60951c:	e918                	sd	a4,16(a0)
  60951e:	6712                	ld	a4,256(sp)
  609520:	e118                	sd	a4,0(a0)
  609522:	cb99                	beqz	a5,609538 <_ZNK4dnnl4impl3cpu4rv6417jit_uni_shuffle_t7executeERKNS0_10exec_ctx_tE+0x1c6>
  609524:	01850913          	addi	s2,a0,24
  609528:	0a2c                	addi	a1,sp,280
  60952a:	854a                	mv	a0,s2
  60952c:	4609                	li	a2,2
  60952e:	9782                	jalr	a5
  609530:	77d2                	ld	a5,304(sp)
  609532:	f81c                	sd	a5,48(s0)
  609534:	77b2                	ld	a5,296(sp)
  609536:	f41c                	sd	a5,40(s0)
  609538:	fffff797          	auipc	a5,0xfffff
  60953c:	62078793          	addi	a5,a5,1568 # 608b58 <_ZNSt17_Function_handlerIFviiEZN4dnnl4implL11parallel_ndElllRKSt8functionIFvlllEEEUliiE_E9_M_invokeERKSt9_Any_dataOiSD_>
  609540:	fdbe                	sd	a5,248(sp)
  609542:	00000797          	auipc	a5,0x0
  609546:	98878793          	addi	a5,a5,-1656 # 608eca <_ZNSt17_Function_handlerIFviiEZN4dnnl4implL11parallel_ndElllRKSt8functionIFvlllEEEUliiE_E10_M_managerERSt9_Any_dataRKSA_St18_Manager_operation>
  60954a:	f1a2                	sd	s0,224(sp)
  60954c:	f9be                	sd	a5,240(sp)
  60954e:	ffa45097          	auipc	ra,0xffa45
  609552:	c22080e7          	jalr	-990(ra) # 4e170 <omp_in_parallel@plt>
  609556:	cd79                	beqz	a0,609634 <_ZNK4dnnl4impl3cpu4rv6417jit_uni_shuffle_t7executeERKNS0_10exec_ctx_tE+0x2c2>
  609558:	77ce                	ld	a5,240(sp)
  60955a:	4705                	li	a4,1
  60955c:	c402                	sw	zero,8(sp)
  60955e:	c23a                	sw	a4,4(sp)
  609560:	14078663          	beqz	a5,6096ac <_ZNK4dnnl4impl3cpu4rv6417jit_uni_shuffle_t7executeERKNS0_10exec_ctx_tE+0x33a>
  609564:	77ee                	ld	a5,248(sp)
  609566:	1180                	addi	s0,sp,224
  609568:	0050                	addi	a2,sp,4
  60956a:	002c                	addi	a1,sp,8
  60956c:	8522                	mv	a0,s0
  60956e:	9782                	jalr	a5
  609570:	77ce                	ld	a5,240(sp)
  609572:	c789                	beqz	a5,60957c <_ZNK4dnnl4impl3cpu4rv6417jit_uni_shuffle_t7executeERKNS0_10exec_ctx_tE+0x20a>
  609574:	85a2                	mv	a1,s0
  609576:	8522                	mv	a0,s0
  609578:	460d                	li	a2,3
  60957a:	9782                	jalr	a5
  60957c:	77b2                	ld	a5,296(sp)
  60957e:	c789                	beqz	a5,609588 <_ZNK4dnnl4impl3cpu4rv6417jit_uni_shuffle_t7executeERKNS0_10exec_ctx_tE+0x216>
  609580:	0a2c                	addi	a1,sp,280
  609582:	460d                	li	a2,3
  609584:	852e                	mv	a0,a1
  609586:	9782                	jalr	a5
  609588:	67ce                	ld	a5,208(sp)
  60958a:	c789                	beqz	a5,609594 <_ZNK4dnnl4impl3cpu4rv6417jit_uni_shuffle_t7executeERKNS0_10exec_ctx_tE+0x222>
  60958c:	018c                	addi	a1,sp,192
  60958e:	460d                	li	a2,3
  609590:	852e                	mv	a0,a1
  609592:	9782                	jalr	a5
  609594:	7772                	ld	a4,312(sp)
  609596:	000ab783          	ld	a5,0(s5)
  60959a:	8fb9                	xor	a5,a5,a4
  60959c:	4701                	li	a4,0
  60959e:	10079363          	bnez	a5,6096a4 <_ZNK4dnnl4impl3cpu4rv6417jit_uni_shuffle_t7executeERKNS0_10exec_ctx_tE+0x332>
  6095a2:	60ba                	ld	ra,392(sp)
  6095a4:	4501                	li	a0,0
  6095a6:	641a                	ld	s0,384(sp)
  6095a8:	74f6                	ld	s1,376(sp)
  6095aa:	7956                	ld	s2,368(sp)
  6095ac:	79b6                	ld	s3,360(sp)
  6095ae:	7a16                	ld	s4,352(sp)
  6095b0:	6af6                	ld	s5,344(sp)
  6095b2:	6b56                	ld	s6,336(sp)
  6095b4:	6bb6                	ld	s7,328(sp)
  6095b6:	6c16                	ld	s8,320(sp)
  6095b8:	6159                	addi	sp,sp,400
  6095ba:	8082                	ret
  6095bc:	8c22                	mv	s8,s0
  6095be:	4401                	li	s0,0
  6095c0:	e98050e3          	blez	s8,609440 <_ZNK4dnnl4impl3cpu4rv6417jit_uni_shuffle_t7executeERKNS0_10exec_ctx_tE+0xce>
  6095c4:	fffc0413          	addi	s0,s8,-1
  6095c8:	03844433          	div	s0,s0,s8
  6095cc:	0405                	addi	s0,s0,1
  6095ce:	bd8d                	j	609440 <_ZNK4dnnl4impl3cpu4rv6417jit_uni_shuffle_t7executeERKNS0_10exec_ctx_tE+0xce>
  6095d0:	ffa45097          	auipc	ra,0xffa45
  6095d4:	ba0080e7          	jalr	-1120(ra) # 4e170 <omp_in_parallel@plt>
  6095d8:	ee0509e3          	beqz	a0,6094ca <_ZNK4dnnl4impl3cpu4rv6417jit_uni_shuffle_t7executeERKNS0_10exec_ctx_tE+0x158>
  6095dc:	b5f5                	j	6094c8 <_ZNK4dnnl4impl3cpu4rv6417jit_uni_shuffle_t7executeERKNS0_10exec_ctx_tE+0x156>
  6095de:	037b0933          	mul	s2,s6,s7
  6095e2:	ffa45097          	auipc	ra,0xffa45
  6095e6:	36e080e7          	jalr	878(ra) # 4e950 <omp_get_max_threads@plt>
  6095ea:	6406                	ld	s0,64(sp)
  6095ec:	fca958e3          	bge	s2,a0,6095bc <_ZNK4dnnl4impl3cpu4rv6417jit_uni_shuffle_t7executeERKNS0_10exec_ctx_tE+0x24a>
  6095f0:	4c01                	li	s8,0
  6095f2:	e2a05be3          	blez	a0,609428 <_ZNK4dnnl4impl3cpu4rv6417jit_uni_shuffle_t7executeERKNS0_10exec_ctx_tE+0xb6>
  6095f6:	157d                	addi	a0,a0,-1
  6095f8:	03254533          	div	a0,a0,s2
  6095fc:	00150c13          	addi	s8,a0,1
  609600:	e28046e3          	bgtz	s0,60942c <_ZNK4dnnl4impl3cpu4rv6417jit_uni_shuffle_t7executeERKNS0_10exec_ctx_tE+0xba>
  609604:	a041                	j	609684 <_ZNK4dnnl4impl3cpu4rv6417jit_uni_shuffle_t7executeERKNS0_10exec_ctx_tE+0x312>
  609606:	ffa45097          	auipc	ra,0xffa45
  60960a:	34a080e7          	jalr	842(ra) # 4e950 <omp_get_max_threads@plt>
  60960e:	84aa                	mv	s1,a0
  609610:	ea0519e3          	bnez	a0,6094c2 <_ZNK4dnnl4impl3cpu4rv6417jit_uni_shuffle_t7executeERKNS0_10exec_ctx_tE+0x150>
  609614:	ffa45097          	auipc	ra,0xffa45
  609618:	b5c080e7          	jalr	-1188(ra) # 4e170 <omp_in_parallel@plt>
  60961c:	c521                	beqz	a0,609664 <_ZNK4dnnl4impl3cpu4rv6417jit_uni_shuffle_t7executeERKNS0_10exec_ctx_tE+0x2f2>
  60961e:	4785                	li	a5,1
  609620:	eaf904e3          	beq	s2,a5,6094c8 <_ZNK4dnnl4impl3cpu4rv6417jit_uni_shuffle_t7executeERKNS0_10exec_ctx_tE+0x156>
  609624:	ffa45097          	auipc	ra,0xffa45
  609628:	b4c080e7          	jalr	-1204(ra) # 4e170 <omp_in_parallel@plt>
  60962c:	bd71                	j	6094c8 <_ZNK4dnnl4impl3cpu4rv6417jit_uni_shuffle_t7executeERKNS0_10exec_ctx_tE+0x156>
  60962e:	4585                	li	a1,1
  609630:	4945                	li	s2,17
  609632:	b361                	j	6093ba <_ZNK4dnnl4impl3cpu4rv6417jit_uni_shuffle_t7executeERKNS0_10exec_ctx_tE+0x48>
  609634:	4785                	li	a5,1
  609636:	f2f481e3          	beq	s1,a5,609558 <_ZNK4dnnl4impl3cpu4rv6417jit_uni_shuffle_t7executeERKNS0_10exec_ctx_tE+0x1e6>
  60963a:	1180                	addi	s0,sp,224
  60963c:	0004861b          	sext.w	a2,s1
  609640:	002c                	addi	a1,sp,8
  609642:	02010623          	sb	zero,44(sp)
  609646:	f002                	sd	zero,32(sp)
  609648:	4681                	li	a3,0
  60964a:	ec02                	sd	zero,24(sp)
  60964c:	fffff517          	auipc	a0,0xfffff
  609650:	68050513          	addi	a0,a0,1664 # 608ccc <_ZN4dnnl4implL8parallelEiRKSt8functionIFviiEE._omp_fn.0>
  609654:	e802                	sd	zero,16(sp)
  609656:	d402                	sw	zero,40(sp)
  609658:	e422                	sd	s0,8(sp)
  60965a:	ffa45097          	auipc	ra,0xffa45
  60965e:	196080e7          	jalr	406(ra) # 4e7f0 <GOMP_parallel@plt>
  609662:	b739                	j	609570 <_ZNK4dnnl4impl3cpu4rv6417jit_uni_shuffle_t7executeERKNS0_10exec_ctx_tE+0x1fe>
  609664:	ffa45097          	auipc	ra,0xffa45
  609668:	2ec080e7          	jalr	748(ra) # 4e950 <omp_get_max_threads@plt>
  60966c:	84aa                	mv	s1,a0
  60966e:	4785                	li	a5,1
  609670:	e4f90ce3          	beq	s2,a5,6094c8 <_ZNK4dnnl4impl3cpu4rv6417jit_uni_shuffle_t7executeERKNS0_10exec_ctx_tE+0x156>
  609674:	ffa45097          	auipc	ra,0xffa45
  609678:	afc080e7          	jalr	-1284(ra) # 4e170 <omp_in_parallel@plt>
  60967c:	e40516e3          	bnez	a0,6094c8 <_ZNK4dnnl4impl3cpu4rv6417jit_uni_shuffle_t7executeERKNS0_10exec_ctx_tE+0x156>
  609680:	d481                	beqz	s1,609588 <_ZNK4dnnl4impl3cpu4rv6417jit_uni_shuffle_t7executeERKNS0_10exec_ctx_tE+0x216>
  609682:	b5a1                	j	6094ca <_ZNK4dnnl4impl3cpu4rv6417jit_uni_shuffle_t7executeERKNS0_10exec_ctx_tE+0x158>
  609684:	4c05                	li	s8,1
  609686:	4401                	li	s0,0
  609688:	bb65                	j	609440 <_ZNK4dnnl4impl3cpu4rv6417jit_uni_shuffle_t7executeERKNS0_10exec_ctx_tE+0xce>
  60968a:	67ce                	ld	a5,208(sp)
  60968c:	842a                	mv	s0,a0
  60968e:	c789                	beqz	a5,609698 <_ZNK4dnnl4impl3cpu4rv6417jit_uni_shuffle_t7executeERKNS0_10exec_ctx_tE+0x326>
  609690:	018c                	addi	a1,sp,192
  609692:	460d                	li	a2,3
  609694:	852e                	mv	a0,a1
  609696:	9782                	jalr	a5
  609698:	7772                	ld	a4,312(sp)
  60969a:	000ab783          	ld	a5,0(s5)
  60969e:	8fb9                	xor	a5,a5,a4
  6096a0:	4701                	li	a4,0
  6096a2:	c3d1                	beqz	a5,609726 <_ZNK4dnnl4impl3cpu4rv6417jit_uni_shuffle_t7executeERKNS0_10exec_ctx_tE+0x3b4>
  6096a4:	ffa45097          	auipc	ra,0xffa45
  6096a8:	2ec080e7          	jalr	748(ra) # 4e990 <__stack_chk_fail@plt>
  6096ac:	7772                	ld	a4,312(sp)
  6096ae:	000ab783          	ld	a5,0(s5)
  6096b2:	8fb9                	xor	a5,a5,a4
  6096b4:	4701                	li	a4,0
  6096b6:	f7fd                	bnez	a5,6096a4 <_ZNK4dnnl4impl3cpu4rv6417jit_uni_shuffle_t7executeERKNS0_10exec_ctx_tE+0x332>
  6096b8:	ffa45097          	auipc	ra,0xffa45
  6096bc:	958080e7          	jalr	-1704(ra) # 4e010 <_ZSt25__throw_bad_function_callv@plt>
  6096c0:	77ce                	ld	a5,240(sp)
  6096c2:	842a                	mv	s0,a0
  6096c4:	cf85                	beqz	a5,6096fc <_ZNK4dnnl4impl3cpu4rv6417jit_uni_shuffle_t7executeERKNS0_10exec_ctx_tE+0x38a>
  6096c6:	118c                	addi	a1,sp,224
  6096c8:	460d                	li	a2,3
  6096ca:	852e                	mv	a0,a1
  6096cc:	9782                	jalr	a5
  6096ce:	a03d                	j	6096fc <_ZNK4dnnl4impl3cpu4rv6417jit_uni_shuffle_t7executeERKNS0_10exec_ctx_tE+0x38a>
  6096d0:	77b2                	ld	a5,296(sp)
  6096d2:	84aa                	mv	s1,a0
  6096d4:	c789                	beqz	a5,6096de <_ZNK4dnnl4impl3cpu4rv6417jit_uni_shuffle_t7executeERKNS0_10exec_ctx_tE+0x36c>
  6096d6:	85a2                	mv	a1,s0
  6096d8:	8522                	mv	a0,s0
  6096da:	460d                	li	a2,3
  6096dc:	9782                	jalr	a5
  6096de:	8426                	mv	s0,s1
  6096e0:	67ce                	ld	a5,208(sp)
  6096e2:	dbdd                	beqz	a5,609698 <_ZNK4dnnl4impl3cpu4rv6417jit_uni_shuffle_t7executeERKNS0_10exec_ctx_tE+0x326>
  6096e4:	018c                	addi	a1,sp,192
  6096e6:	460d                	li	a2,3
  6096e8:	852e                	mv	a0,a1
  6096ea:	9782                	jalr	a5
  6096ec:	b775                	j	609698 <_ZNK4dnnl4impl3cpu4rv6417jit_uni_shuffle_t7executeERKNS0_10exec_ctx_tE+0x326>
  6096ee:	842a                	mv	s0,a0
  6096f0:	77ce                	ld	a5,240(sp)
  6096f2:	c789                	beqz	a5,6096fc <_ZNK4dnnl4impl3cpu4rv6417jit_uni_shuffle_t7executeERKNS0_10exec_ctx_tE+0x38a>
  6096f4:	118c                	addi	a1,sp,224
  6096f6:	460d                	li	a2,3
  6096f8:	852e                	mv	a0,a1
  6096fa:	9782                	jalr	a5
  6096fc:	77b2                	ld	a5,296(sp)
  6096fe:	d3ed                	beqz	a5,6096e0 <_ZNK4dnnl4impl3cpu4rv6417jit_uni_shuffle_t7executeERKNS0_10exec_ctx_tE+0x36e>
  609700:	0a2c                	addi	a1,sp,280
  609702:	460d                	li	a2,3
  609704:	852e                	mv	a0,a1
  609706:	9782                	jalr	a5
  609708:	bfe1                	j	6096e0 <_ZNK4dnnl4impl3cpu4rv6417jit_uni_shuffle_t7executeERKNS0_10exec_ctx_tE+0x36e>
  60970a:	741c                	ld	a5,40(s0)
  60970c:	84aa                	mv	s1,a0
  60970e:	c789                	beqz	a5,609718 <_ZNK4dnnl4impl3cpu4rv6417jit_uni_shuffle_t7executeERKNS0_10exec_ctx_tE+0x3a6>
  609710:	85ca                	mv	a1,s2
  609712:	854a                	mv	a0,s2
  609714:	460d                	li	a2,3
  609716:	9782                	jalr	a5
  609718:	8522                	mv	a0,s0
  60971a:	8426                	mv	s0,s1
  60971c:	ffa45097          	auipc	ra,0xffa45
  609720:	d14080e7          	jalr	-748(ra) # 4e430 <_ZdlPv@plt>
  609724:	b7f1                	j	6096f0 <_ZNK4dnnl4impl3cpu4rv6417jit_uni_shuffle_t7executeERKNS0_10exec_ctx_tE+0x37e>
  609726:	8522                	mv	a0,s0
  609728:	ffa45097          	auipc	ra,0xffa45
  60972c:	2c8080e7          	jalr	712(ra) # 4e9f0 <_Unwind_Resume@plt>

0000000000609730 <_ZN4dnnl4impl3cpu4rv6417jit_uni_shuffle_tD1Ev>:
  609730:	1101                	addi	sp,sp,-32
  609732:	00128797          	auipc	a5,0x128
  609736:	16e78793          	addi	a5,a5,366 # 7318a0 <_ZTVN4dnnl4impl3cpu4rv6417jit_uni_shuffle_tE+0x10>
  60973a:	e822                	sd	s0,16(sp)
  60973c:	842a                	mv	s0,a0
  60973e:	6128                	ld	a0,64(a0)
  609740:	ec06                	sd	ra,24(sp)
  609742:	e426                	sd	s1,8(sp)
  609744:	e04a                	sd	s2,0(sp)
  609746:	e01c                	sd	a5,0(s0)
  609748:	ffbc7097          	auipc	ra,0xffbc7
  60974c:	be2080e7          	jalr	-1054(ra) # 1d032a <_ZN4dnnl4impl4freeEPv>
  609750:	7c08                	ld	a0,56(s0)
  609752:	c501                	beqz	a0,60975a <_ZN4dnnl4impl3cpu4rv6417jit_uni_shuffle_tD1Ev+0x2a>
  609754:	611c                	ld	a5,0(a0)
  609756:	679c                	ld	a5,8(a5)
  609758:	9782                	jalr	a5
  60975a:	7404                	ld	s1,40(s0)
  60975c:	0012b797          	auipc	a5,0x12b
  609760:	5cc78793          	addi	a5,a5,1484 # 734d28 <_ZTVN4dnnl4impl11primitive_tE+0x10>
  609764:	e01c                	sd	a5,0(s0)
  609766:	cc99                	beqz	s1,609784 <_ZN4dnnl4impl3cpu4rv6417jit_uni_shuffle_tD1Ev+0x54>
  609768:	00133917          	auipc	s2,0x133
  60976c:	69893903          	ld	s2,1688(s2) # 73ce00 <__libc_single_threaded@GLIBC_2.32>
  609770:	00094783          	lbu	a5,0(s2)
  609774:	cf95                	beqz	a5,6097b0 <_ZN4dnnl4impl3cpu4rv6417jit_uni_shuffle_tD1Ev+0x80>
  609776:	589c                	lw	a5,48(s1)
  609778:	fff7871b          	addiw	a4,a5,-1
  60977c:	d898                	sw	a4,48(s1)
  60977e:	4705                	li	a4,1
  609780:	04e78163          	beq	a5,a4,6097c2 <_ZN4dnnl4impl3cpu4rv6417jit_uni_shuffle_tD1Ev+0x92>
  609784:	6800                	ld	s0,16(s0)
  609786:	cc19                	beqz	s0,6097a4 <_ZN4dnnl4impl3cpu4rv6417jit_uni_shuffle_tD1Ev+0x74>
  609788:	00133917          	auipc	s2,0x133
  60978c:	67893903          	ld	s2,1656(s2) # 73ce00 <__libc_single_threaded@GLIBC_2.32>
  609790:	00094783          	lbu	a5,0(s2)
  609794:	cfa1                	beqz	a5,6097ec <_ZN4dnnl4impl3cpu4rv6417jit_uni_shuffle_tD1Ev+0xbc>
  609796:	581c                	lw	a5,48(s0)
  609798:	fff7871b          	addiw	a4,a5,-1
  60979c:	d818                	sw	a4,48(s0)
  60979e:	4705                	li	a4,1
  6097a0:	04e78f63          	beq	a5,a4,6097fe <_ZN4dnnl4impl3cpu4rv6417jit_uni_shuffle_tD1Ev+0xce>
  6097a4:	60e2                	ld	ra,24(sp)
  6097a6:	6442                	ld	s0,16(sp)
  6097a8:	64a2                	ld	s1,8(sp)
  6097aa:	6902                	ld	s2,0(sp)
  6097ac:	6105                	addi	sp,sp,32
  6097ae:	8082                	ret
  6097b0:	03048693          	addi	a3,s1,48
  6097b4:	577d                	li	a4,-1
  6097b6:	06e6a7af          	amoadd.w.aqrl	a5,a4,(a3)
  6097ba:	2781                	sext.w	a5,a5
  6097bc:	4705                	li	a4,1
  6097be:	fce793e3          	bne	a5,a4,609784 <_ZN4dnnl4impl3cpu4rv6417jit_uni_shuffle_tD1Ev+0x54>
  6097c2:	609c                	ld	a5,0(s1)
  6097c4:	8526                	mv	a0,s1
  6097c6:	6b9c                	ld	a5,16(a5)
  6097c8:	9782                	jalr	a5
  6097ca:	8330000f          	fence.tso
  6097ce:	00094783          	lbu	a5,0(s2)
  6097d2:	c7b5                	beqz	a5,60983e <_ZN4dnnl4impl3cpu4rv6417jit_uni_shuffle_tD1Ev+0x10e>
  6097d4:	58dc                	lw	a5,52(s1)
  6097d6:	fff7871b          	addiw	a4,a5,-1
  6097da:	d8d8                	sw	a4,52(s1)
  6097dc:	4705                	li	a4,1
  6097de:	fae793e3          	bne	a5,a4,609784 <_ZN4dnnl4impl3cpu4rv6417jit_uni_shuffle_tD1Ev+0x54>
  6097e2:	609c                	ld	a5,0(s1)
  6097e4:	8526                	mv	a0,s1
  6097e6:	6f9c                	ld	a5,24(a5)
  6097e8:	9782                	jalr	a5
  6097ea:	bf69                	j	609784 <_ZN4dnnl4impl3cpu4rv6417jit_uni_shuffle_tD1Ev+0x54>
  6097ec:	03040693          	addi	a3,s0,48
  6097f0:	577d                	li	a4,-1
  6097f2:	06e6a7af          	amoadd.w.aqrl	a5,a4,(a3)
  6097f6:	2781                	sext.w	a5,a5
  6097f8:	4705                	li	a4,1
  6097fa:	fae795e3          	bne	a5,a4,6097a4 <_ZN4dnnl4impl3cpu4rv6417jit_uni_shuffle_tD1Ev+0x74>
  6097fe:	601c                	ld	a5,0(s0)
  609800:	8522                	mv	a0,s0
  609802:	6b9c                	ld	a5,16(a5)
  609804:	9782                	jalr	a5
  609806:	8330000f          	fence.tso
  60980a:	00094783          	lbu	a5,0(s2)
  60980e:	c38d                	beqz	a5,609830 <_ZN4dnnl4impl3cpu4rv6417jit_uni_shuffle_tD1Ev+0x100>
  609810:	585c                	lw	a5,52(s0)
  609812:	fff7871b          	addiw	a4,a5,-1
  609816:	d858                	sw	a4,52(s0)
  609818:	4705                	li	a4,1
  60981a:	f8e795e3          	bne	a5,a4,6097a4 <_ZN4dnnl4impl3cpu4rv6417jit_uni_shuffle_tD1Ev+0x74>
  60981e:	601c                	ld	a5,0(s0)
  609820:	8522                	mv	a0,s0
  609822:	6442                	ld	s0,16(sp)
  609824:	60e2                	ld	ra,24(sp)
  609826:	64a2                	ld	s1,8(sp)
  609828:	6902                	ld	s2,0(sp)
  60982a:	6f9c                	ld	a5,24(a5)
  60982c:	6105                	addi	sp,sp,32
  60982e:	8782                	jr	a5
  609830:	03440693          	addi	a3,s0,52
  609834:	577d                	li	a4,-1
  609836:	06e6a7af          	amoadd.w.aqrl	a5,a4,(a3)
  60983a:	2781                	sext.w	a5,a5
  60983c:	bff1                	j	609818 <_ZN4dnnl4impl3cpu4rv6417jit_uni_shuffle_tD1Ev+0xe8>
  60983e:	03448693          	addi	a3,s1,52
  609842:	577d                	li	a4,-1
  609844:	06e6a7af          	amoadd.w.aqrl	a5,a4,(a3)
  609848:	2781                	sext.w	a5,a5
  60984a:	bf49                	j	6097dc <_ZN4dnnl4impl3cpu4rv6417jit_uni_shuffle_tD1Ev+0xac>

000000000060984c <_ZN4dnnl4impl3cpu4rv6417jit_uni_shuffle_tD0Ev>:
  60984c:	1101                	addi	sp,sp,-32
  60984e:	00128797          	auipc	a5,0x128
  609852:	05278793          	addi	a5,a5,82 # 7318a0 <_ZTVN4dnnl4impl3cpu4rv6417jit_uni_shuffle_tE+0x10>
  609856:	e822                	sd	s0,16(sp)
  609858:	842a                	mv	s0,a0
  60985a:	6128                	ld	a0,64(a0)
  60985c:	ec06                	sd	ra,24(sp)
  60985e:	e426                	sd	s1,8(sp)
  609860:	e04a                	sd	s2,0(sp)
  609862:	e01c                	sd	a5,0(s0)
  609864:	ffbc7097          	auipc	ra,0xffbc7
  609868:	ac6080e7          	jalr	-1338(ra) # 1d032a <_ZN4dnnl4impl4freeEPv>
  60986c:	7c08                	ld	a0,56(s0)
  60986e:	c501                	beqz	a0,609876 <_ZN4dnnl4impl3cpu4rv6417jit_uni_shuffle_tD0Ev+0x2a>
  609870:	611c                	ld	a5,0(a0)
  609872:	679c                	ld	a5,8(a5)
  609874:	9782                	jalr	a5
  609876:	7404                	ld	s1,40(s0)
  609878:	0012b797          	auipc	a5,0x12b
  60987c:	4b078793          	addi	a5,a5,1200 # 734d28 <_ZTVN4dnnl4impl11primitive_tE+0x10>
  609880:	e01c                	sd	a5,0(s0)
  609882:	cc99                	beqz	s1,6098a0 <_ZN4dnnl4impl3cpu4rv6417jit_uni_shuffle_tD0Ev+0x54>
  609884:	00133917          	auipc	s2,0x133
  609888:	57c93903          	ld	s2,1404(s2) # 73ce00 <__libc_single_threaded@GLIBC_2.32>
  60988c:	00094783          	lbu	a5,0(s2)
  609890:	c3b1                	beqz	a5,6098d4 <_ZN4dnnl4impl3cpu4rv6417jit_uni_shuffle_tD0Ev+0x88>
  609892:	589c                	lw	a5,48(s1)
  609894:	fff7871b          	addiw	a4,a5,-1
  609898:	d898                	sw	a4,48(s1)
  60989a:	4705                	li	a4,1
  60989c:	04e78563          	beq	a5,a4,6098e6 <_ZN4dnnl4impl3cpu4rv6417jit_uni_shuffle_tD0Ev+0x9a>
  6098a0:	6804                	ld	s1,16(s0)
  6098a2:	cc99                	beqz	s1,6098c0 <_ZN4dnnl4impl3cpu4rv6417jit_uni_shuffle_tD0Ev+0x74>
  6098a4:	00133917          	auipc	s2,0x133
  6098a8:	55c93903          	ld	s2,1372(s2) # 73ce00 <__libc_single_threaded@GLIBC_2.32>
  6098ac:	00094783          	lbu	a5,0(s2)
  6098b0:	c3a5                	beqz	a5,609910 <_ZN4dnnl4impl3cpu4rv6417jit_uni_shuffle_tD0Ev+0xc4>
  6098b2:	589c                	lw	a5,48(s1)
  6098b4:	fff7871b          	addiw	a4,a5,-1
  6098b8:	d898                	sw	a4,48(s1)
  6098ba:	4705                	li	a4,1
  6098bc:	06e78363          	beq	a5,a4,609922 <_ZN4dnnl4impl3cpu4rv6417jit_uni_shuffle_tD0Ev+0xd6>
  6098c0:	8522                	mv	a0,s0
  6098c2:	6442                	ld	s0,16(sp)
  6098c4:	60e2                	ld	ra,24(sp)
  6098c6:	64a2                	ld	s1,8(sp)
  6098c8:	6902                	ld	s2,0(sp)
  6098ca:	6105                	addi	sp,sp,32
  6098cc:	ffa45317          	auipc	t1,0xffa45
  6098d0:	b6430067          	jr	-1180(t1) # 4e430 <_ZdlPv@plt>
  6098d4:	03048693          	addi	a3,s1,48
  6098d8:	577d                	li	a4,-1
  6098da:	06e6a7af          	amoadd.w.aqrl	a5,a4,(a3)
  6098de:	2781                	sext.w	a5,a5
  6098e0:	4705                	li	a4,1
  6098e2:	fae79fe3          	bne	a5,a4,6098a0 <_ZN4dnnl4impl3cpu4rv6417jit_uni_shuffle_tD0Ev+0x54>
  6098e6:	609c                	ld	a5,0(s1)
  6098e8:	8526                	mv	a0,s1
  6098ea:	6b9c                	ld	a5,16(a5)
  6098ec:	9782                	jalr	a5
  6098ee:	8330000f          	fence.tso
  6098f2:	00094783          	lbu	a5,0(s2)
  6098f6:	c3b5                	beqz	a5,60995a <_ZN4dnnl4impl3cpu4rv6417jit_uni_shuffle_tD0Ev+0x10e>
  6098f8:	58dc                	lw	a5,52(s1)
  6098fa:	fff7871b          	addiw	a4,a5,-1
  6098fe:	d8d8                	sw	a4,52(s1)
  609900:	4705                	li	a4,1
  609902:	f8e79fe3          	bne	a5,a4,6098a0 <_ZN4dnnl4impl3cpu4rv6417jit_uni_shuffle_tD0Ev+0x54>
  609906:	609c                	ld	a5,0(s1)
  609908:	8526                	mv	a0,s1
  60990a:	6f9c                	ld	a5,24(a5)
  60990c:	9782                	jalr	a5
  60990e:	bf49                	j	6098a0 <_ZN4dnnl4impl3cpu4rv6417jit_uni_shuffle_tD0Ev+0x54>
  609910:	03048693          	addi	a3,s1,48
  609914:	577d                	li	a4,-1
  609916:	06e6a7af          	amoadd.w.aqrl	a5,a4,(a3)
  60991a:	2781                	sext.w	a5,a5
  60991c:	4705                	li	a4,1
  60991e:	fae791e3          	bne	a5,a4,6098c0 <_ZN4dnnl4impl3cpu4rv6417jit_uni_shuffle_tD0Ev+0x74>
  609922:	609c                	ld	a5,0(s1)
  609924:	8526                	mv	a0,s1
  609926:	6b9c                	ld	a5,16(a5)
  609928:	9782                	jalr	a5
  60992a:	8330000f          	fence.tso
  60992e:	00094783          	lbu	a5,0(s2)
  609932:	cf89                	beqz	a5,60994c <_ZN4dnnl4impl3cpu4rv6417jit_uni_shuffle_tD0Ev+0x100>
  609934:	58dc                	lw	a5,52(s1)
  609936:	fff7871b          	addiw	a4,a5,-1
  60993a:	d8d8                	sw	a4,52(s1)
  60993c:	4705                	li	a4,1
  60993e:	f8e791e3          	bne	a5,a4,6098c0 <_ZN4dnnl4impl3cpu4rv6417jit_uni_shuffle_tD0Ev+0x74>
  609942:	609c                	ld	a5,0(s1)
  609944:	8526                	mv	a0,s1
  609946:	6f9c                	ld	a5,24(a5)
  609948:	9782                	jalr	a5
  60994a:	bf9d                	j	6098c0 <_ZN4dnnl4impl3cpu4rv6417jit_uni_shuffle_tD0Ev+0x74>
  60994c:	03448693          	addi	a3,s1,52
  609950:	577d                	li	a4,-1
  609952:	06e6a7af          	amoadd.w.aqrl	a5,a4,(a3)
  609956:	2781                	sext.w	a5,a5
  609958:	b7d5                	j	60993c <_ZN4dnnl4impl3cpu4rv6417jit_uni_shuffle_tD0Ev+0xf0>
  60995a:	03448693          	addi	a3,s1,52
  60995e:	577d                	li	a4,-1
  609960:	06e6a7af          	amoadd.w.aqrl	a5,a4,(a3)
  609964:	2781                	sext.w	a5,a5
  609966:	bf69                	j	609900 <_ZN4dnnl4impl3cpu4rv6417jit_uni_shuffle_tD0Ev+0xb4>

0000000000609968 <_ZNSt8_Rb_treeIiSt4pairIKiN4dnnl4impl13quant_entry_tEESt10_Select1stIS5_ESt4lessIiESaIS5_EE8_M_eraseEPSt13_Rb_tree_nodeIS5_E.isra.0>:
  609968:	10050963          	beqz	a0,609a7a <_ZNSt8_Rb_treeIiSt4pairIKiN4dnnl4impl13quant_entry_tEESt10_Select1stIS5_ESt4lessIiESaIS5_EE8_M_eraseEPSt13_Rb_tree_nodeIS5_E.isra.0+0x112>
  60996c:	715d                	addi	sp,sp,-80
  60996e:	ec56                	sd	s5,24(sp)
  609970:	8aaa                	mv	s5,a0
  609972:	e486                	sd	ra,72(sp)
  609974:	e85a                	sd	s6,16(sp)
  609976:	018abb03          	ld	s6,24(s5)
  60997a:	0e0b0263          	beqz	s6,609a5e <_ZNSt8_Rb_treeIiSt4pairIKiN4dnnl4impl13quant_entry_tEESt10_Select1stIS5_ESt4lessIiESaIS5_EE8_M_eraseEPSt13_Rb_tree_nodeIS5_E.isra.0+0xf6>
  60997e:	e0a2                	sd	s0,64(sp)
  609980:	f84a                	sd	s2,48(sp)
  609982:	e45e                	sd	s7,8(sp)
  609984:	e062                	sd	s8,0(sp)
  609986:	018b3b83          	ld	s7,24(s6)
  60998a:	0a0b8d63          	beqz	s7,609a44 <_ZNSt8_Rb_treeIiSt4pairIKiN4dnnl4impl13quant_entry_tEESt10_Select1stIS5_ESt4lessIiESaIS5_EE8_M_eraseEPSt13_Rb_tree_nodeIS5_E.isra.0+0xdc>
  60998e:	018bbc03          	ld	s8,24(s7)
  609992:	0a0c0063          	beqz	s8,609a32 <_ZNSt8_Rb_treeIiSt4pairIKiN4dnnl4impl13quant_entry_tEESt10_Select1stIS5_ESt4lessIiESaIS5_EE8_M_eraseEPSt13_Rb_tree_nodeIS5_E.isra.0+0xca>
  609996:	018c3403          	ld	s0,24(s8)
  60999a:	c059                	beqz	s0,609a20 <_ZNSt8_Rb_treeIiSt4pairIKiN4dnnl4impl13quant_entry_tEESt10_Select1stIS5_ESt4lessIiESaIS5_EE8_M_eraseEPSt13_Rb_tree_nodeIS5_E.isra.0+0xb8>
  60999c:	01843903          	ld	s2,24(s0)
  6099a0:	06090963          	beqz	s2,609a12 <_ZNSt8_Rb_treeIiSt4pairIKiN4dnnl4impl13quant_entry_tEESt10_Select1stIS5_ESt4lessIiESaIS5_EE8_M_eraseEPSt13_Rb_tree_nodeIS5_E.isra.0+0xaa>
  6099a4:	f44e                	sd	s3,40(sp)
  6099a6:	01893983          	ld	s3,24(s2)
  6099aa:	04098a63          	beqz	s3,6099fe <_ZNSt8_Rb_treeIiSt4pairIKiN4dnnl4impl13quant_entry_tEESt10_Select1stIS5_ESt4lessIiESaIS5_EE8_M_eraseEPSt13_Rb_tree_nodeIS5_E.isra.0+0x96>
  6099ae:	fc26                	sd	s1,56(sp)
  6099b0:	f052                	sd	s4,32(sp)
  6099b2:	0189b483          	ld	s1,24(s3)
  6099b6:	c88d                	beqz	s1,6099e8 <_ZNSt8_Rb_treeIiSt4pairIKiN4dnnl4impl13quant_entry_tEESt10_Select1stIS5_ESt4lessIiESaIS5_EE8_M_eraseEPSt13_Rb_tree_nodeIS5_E.isra.0+0x80>
  6099b8:	0184ba03          	ld	s4,24(s1)
  6099bc:	000a0f63          	beqz	s4,6099da <_ZNSt8_Rb_treeIiSt4pairIKiN4dnnl4impl13quant_entry_tEESt10_Select1stIS5_ESt4lessIiESaIS5_EE8_M_eraseEPSt13_Rb_tree_nodeIS5_E.isra.0+0x72>
  6099c0:	018a3503          	ld	a0,24(s4)
  6099c4:	fa5ff0ef          	jal	609968 <_ZNSt8_Rb_treeIiSt4pairIKiN4dnnl4impl13quant_entry_tEESt10_Select1stIS5_ESt4lessIiESaIS5_EE8_M_eraseEPSt13_Rb_tree_nodeIS5_E.isra.0>
  6099c8:	8552                	mv	a0,s4
  6099ca:	010a3a03          	ld	s4,16(s4)
  6099ce:	ffa45097          	auipc	ra,0xffa45
  6099d2:	a62080e7          	jalr	-1438(ra) # 4e430 <_ZdlPv@plt>
  6099d6:	fe0a15e3          	bnez	s4,6099c0 <_ZNSt8_Rb_treeIiSt4pairIKiN4dnnl4impl13quant_entry_tEESt10_Select1stIS5_ESt4lessIiESaIS5_EE8_M_eraseEPSt13_Rb_tree_nodeIS5_E.isra.0+0x58>
  6099da:	8526                	mv	a0,s1
  6099dc:	6884                	ld	s1,16(s1)
  6099de:	ffa45097          	auipc	ra,0xffa45
  6099e2:	a52080e7          	jalr	-1454(ra) # 4e430 <_ZdlPv@plt>
  6099e6:	f8e9                	bnez	s1,6099b8 <_ZNSt8_Rb_treeIiSt4pairIKiN4dnnl4impl13quant_entry_tEESt10_Select1stIS5_ESt4lessIiESaIS5_EE8_M_eraseEPSt13_Rb_tree_nodeIS5_E.isra.0+0x50>
  6099e8:	854e                	mv	a0,s3
  6099ea:	0109b983          	ld	s3,16(s3)
  6099ee:	ffa45097          	auipc	ra,0xffa45
  6099f2:	a42080e7          	jalr	-1470(ra) # 4e430 <_ZdlPv@plt>
  6099f6:	fa099ee3          	bnez	s3,6099b2 <_ZNSt8_Rb_treeIiSt4pairIKiN4dnnl4impl13quant_entry_tEESt10_Select1stIS5_ESt4lessIiESaIS5_EE8_M_eraseEPSt13_Rb_tree_nodeIS5_E.isra.0+0x4a>
  6099fa:	74e2                	ld	s1,56(sp)
  6099fc:	7a02                	ld	s4,32(sp)
  6099fe:	854a                	mv	a0,s2
  609a00:	01093903          	ld	s2,16(s2)
  609a04:	ffa45097          	auipc	ra,0xffa45
  609a08:	a2c080e7          	jalr	-1492(ra) # 4e430 <_ZdlPv@plt>
  609a0c:	f8091de3          	bnez	s2,6099a6 <_ZNSt8_Rb_treeIiSt4pairIKiN4dnnl4impl13quant_entry_tEESt10_Select1stIS5_ESt4lessIiESaIS5_EE8_M_eraseEPSt13_Rb_tree_nodeIS5_E.isra.0+0x3e>
  609a10:	79a2                	ld	s3,40(sp)
  609a12:	8522                	mv	a0,s0
  609a14:	6800                	ld	s0,16(s0)
  609a16:	ffa45097          	auipc	ra,0xffa45
  609a1a:	a1a080e7          	jalr	-1510(ra) # 4e430 <_ZdlPv@plt>
  609a1e:	fc3d                	bnez	s0,60999c <_ZNSt8_Rb_treeIiSt4pairIKiN4dnnl4impl13quant_entry_tEESt10_Select1stIS5_ESt4lessIiESaIS5_EE8_M_eraseEPSt13_Rb_tree_nodeIS5_E.isra.0+0x34>
  609a20:	8562                	mv	a0,s8
  609a22:	010c3c03          	ld	s8,16(s8)
  609a26:	ffa45097          	auipc	ra,0xffa45
  609a2a:	a0a080e7          	jalr	-1526(ra) # 4e430 <_ZdlPv@plt>
  609a2e:	f60c14e3          	bnez	s8,609996 <_ZNSt8_Rb_treeIiSt4pairIKiN4dnnl4impl13quant_entry_tEESt10_Select1stIS5_ESt4lessIiESaIS5_EE8_M_eraseEPSt13_Rb_tree_nodeIS5_E.isra.0+0x2e>
  609a32:	855e                	mv	a0,s7
  609a34:	010bbb83          	ld	s7,16(s7)
  609a38:	ffa45097          	auipc	ra,0xffa45
  609a3c:	9f8080e7          	jalr	-1544(ra) # 4e430 <_ZdlPv@plt>
  609a40:	f40b97e3          	bnez	s7,60998e <_ZNSt8_Rb_treeIiSt4pairIKiN4dnnl4impl13quant_entry_tEESt10_Select1stIS5_ESt4lessIiESaIS5_EE8_M_eraseEPSt13_Rb_tree_nodeIS5_E.isra.0+0x26>
  609a44:	855a                	mv	a0,s6
  609a46:	010b3b03          	ld	s6,16(s6)
  609a4a:	ffa45097          	auipc	ra,0xffa45
  609a4e:	9e6080e7          	jalr	-1562(ra) # 4e430 <_ZdlPv@plt>
  609a52:	f20b1ae3          	bnez	s6,609986 <_ZNSt8_Rb_treeIiSt4pairIKiN4dnnl4impl13quant_entry_tEESt10_Select1stIS5_ESt4lessIiESaIS5_EE8_M_eraseEPSt13_Rb_tree_nodeIS5_E.isra.0+0x1e>
  609a56:	6406                	ld	s0,64(sp)
  609a58:	7942                	ld	s2,48(sp)
  609a5a:	6ba2                	ld	s7,8(sp)
  609a5c:	6c02                	ld	s8,0(sp)
  609a5e:	8556                	mv	a0,s5
  609a60:	010aba83          	ld	s5,16(s5)
  609a64:	ffa45097          	auipc	ra,0xffa45
  609a68:	9cc080e7          	jalr	-1588(ra) # 4e430 <_ZdlPv@plt>
  609a6c:	f00a95e3          	bnez	s5,609976 <_ZNSt8_Rb_treeIiSt4pairIKiN4dnnl4impl13quant_entry_tEESt10_Select1stIS5_ESt4lessIiESaIS5_EE8_M_eraseEPSt13_Rb_tree_nodeIS5_E.isra.0+0xe>
  609a70:	60a6                	ld	ra,72(sp)
  609a72:	6ae2                	ld	s5,24(sp)
  609a74:	6b42                	ld	s6,16(sp)
  609a76:	6161                	addi	sp,sp,80
  609a78:	8082                	ret
  609a7a:	8082                	ret
