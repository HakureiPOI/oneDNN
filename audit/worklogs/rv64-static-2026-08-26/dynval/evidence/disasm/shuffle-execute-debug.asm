# Disassembly of jit_uni_shuffle_t::execute (debug libdnnl.so.3.14) — abort path reference
# command: objdump -d --start-address=0x8af284 --stop-address=0x8af7a4 ~/onednn-verify/build-dbg/src/libdnnl.so.3.14
# symbol: execute @ 0x8af284; next symbol (std::function ctor) @ 0x8af7a4
# purpose: RV64-004 debug path — the div_up assertion (assert b>0) fires here


/root/onednn-verify/build-dbg/src/libdnnl.so.3.14：     文件格式 elf64-littleriscv


Disassembly of section .text:

00000000008af284 <_ZNK4dnnl4impl3cpu4rv6417jit_uni_shuffle_t7executeERKNS0_10exec_ctx_tE>:
  8af284:	7129                	addi	sp,sp,-320
  8af286:	fe06                	sd	ra,312(sp)
  8af288:	fa22                	sd	s0,304(sp)
  8af28a:	f626                	sd	s1,296(sp)
  8af28c:	0280                	addi	s0,sp,320
  8af28e:	eca43423          	sd	a0,-312(s0)
  8af292:	ecb43023          	sd	a1,-320(s0)
  8af296:	005eb797          	auipc	a5,0x5eb
  8af29a:	7a27b783          	ld	a5,1954(a5) # e9aa38 <__stack_chk_guard@GLIBC_2.27>
  8af29e:	6398                	ld	a4,0(a5)
  8af2a0:	fce43c23          	sd	a4,-40(s0)
  8af2a4:	4701                	li	a4,0
  8af2a6:	ec843503          	ld	a0,-312(s0)
  8af2aa:	780030ef          	jal	8b2a2a <_ZNK4dnnl4impl3cpu4rv6417jit_uni_shuffle_t2pdEv>
  8af2ae:	87aa                	mv	a5,a0
  8af2b0:	853e                	mv	a0,a5
  8af2b2:	ffa83097          	auipc	ra,0xffa83
  8af2b6:	eaa080e7          	jalr	-342(ra) # 33215c <_ZNK4dnnl4impl12shuffle_pd_t6is_fwdEv>
  8af2ba:	87aa                	mv	a5,a0
  8af2bc:	c399                	beqz	a5,8af2c2 <_ZNK4dnnl4impl3cpu4rv6417jit_uni_shuffle_t7executeERKNS0_10exec_ctx_tE+0x3e>
  8af2be:	4785                	li	a5,1
  8af2c0:	a019                	j	8af2c6 <_ZNK4dnnl4impl3cpu4rv6417jit_uni_shuffle_t7executeERKNS0_10exec_ctx_tE+0x42>
  8af2c2:	09100793          	li	a5,145
  8af2c6:	ecf42e23          	sw	a5,-292(s0)
  8af2ca:	ec843503          	ld	a0,-312(s0)
  8af2ce:	75c030ef          	jal	8b2a2a <_ZNK4dnnl4impl3cpu4rv6417jit_uni_shuffle_t2pdEv>
  8af2d2:	87aa                	mv	a5,a0
  8af2d4:	853e                	mv	a0,a5
  8af2d6:	ffa83097          	auipc	ra,0xffa83
  8af2da:	e86080e7          	jalr	-378(ra) # 33215c <_ZNK4dnnl4impl12shuffle_pd_t6is_fwdEv>
  8af2de:	87aa                	mv	a5,a0
  8af2e0:	c399                	beqz	a5,8af2e6 <_ZNK4dnnl4impl3cpu4rv6417jit_uni_shuffle_t7executeERKNS0_10exec_ctx_tE+0x62>
  8af2e2:	47c5                	li	a5,17
  8af2e4:	a019                	j	8af2ea <_ZNK4dnnl4impl3cpu4rv6417jit_uni_shuffle_t7executeERKNS0_10exec_ctx_tE+0x66>
  8af2e6:	08100793          	li	a5,129
  8af2ea:	eef42023          	sw	a5,-288(s0)
  8af2ee:	edc42783          	lw	a5,-292(s0)
  8af2f2:	4701                	li	a4,0
  8af2f4:	4681                	li	a3,0
  8af2f6:	4601                	li	a2,0
  8af2f8:	85be                	mv	a1,a5
  8af2fa:	ec043503          	ld	a0,-320(s0)
  8af2fe:	ff9c0097          	auipc	ra,0xff9c0
  8af302:	828080e7          	jalr	-2008(ra) # 26eb26 <_ZNK4dnnl4impl10exec_ctx_t8host_ptrEibP13dnnl_status_ti>
  8af306:	87aa                	mv	a5,a0
  8af308:	eef43823          	sd	a5,-272(s0)
  8af30c:	ee042783          	lw	a5,-288(s0)
  8af310:	4701                	li	a4,0
  8af312:	4681                	li	a3,0
  8af314:	4601                	li	a2,0
  8af316:	85be                	mv	a1,a5
  8af318:	ec043503          	ld	a0,-320(s0)
  8af31c:	ff9c0097          	auipc	ra,0xff9c0
  8af320:	80a080e7          	jalr	-2038(ra) # 26eb26 <_ZNK4dnnl4impl10exec_ctx_t8host_ptrEibP13dnnl_status_ti>
  8af324:	87aa                	mv	a5,a0
  8af326:	eef43c23          	sd	a5,-264(s0)
  8af32a:	ec843503          	ld	a0,-312(s0)
  8af32e:	6fc030ef          	jal	8b2a2a <_ZNK4dnnl4impl3cpu4rv6417jit_uni_shuffle_t2pdEv>
  8af332:	87aa                	mv	a5,a0
  8af334:	853e                	mv	a0,a5
  8af336:	6d6030ef          	jal	8b2a0c <_ZNK4dnnl4impl3cpu4rv6417jit_uni_shuffle_t4pd_t8get_confEv>
  8af33a:	87aa                	mv	a5,a0
  8af33c:	0007b803          	ld	a6,0(a5)
  8af340:	6788                	ld	a0,8(a5)
  8af342:	6b8c                	ld	a1,16(a5)
  8af344:	6f90                	ld	a2,24(a5)
  8af346:	7394                	ld	a3,32(a5)
  8af348:	7798                	ld	a4,40(a5)
  8af34a:	7b9c                	ld	a5,48(a5)
  8af34c:	f3043423          	sd	a6,-216(s0)
  8af350:	f2a43823          	sd	a0,-208(s0)
  8af354:	f2b43c23          	sd	a1,-200(s0)
  8af358:	f4c43023          	sd	a2,-192(s0)
  8af35c:	f4d43423          	sd	a3,-184(s0)
  8af360:	f4e43823          	sd	a4,-176(s0)
  8af364:	f4f43c23          	sd	a5,-168(s0)
  8af368:	f2843783          	ld	a5,-216(s0)
  8af36c:	f0f43023          	sd	a5,-256(s0)
  8af370:	f5843783          	ld	a5,-168(s0)
  8af374:	f0f43423          	sd	a5,-248(s0)
  8af378:	ff821097          	auipc	ra,0xff821
  8af37c:	d20080e7          	jalr	-736(ra) # d0098 <_Z28dnnl_get_current_num_threadsv>
  8af380:	87aa                	mv	a5,a0
  8af382:	eef42223          	sw	a5,-284(s0)
  8af386:	f0043703          	ld	a4,-256(s0)
  8af38a:	f0843783          	ld	a5,-248(s0)
  8af38e:	02f707b3          	mul	a5,a4,a5
  8af392:	f0f43823          	sd	a5,-240(s0)
  8af396:	ee442783          	lw	a5,-284(s0)
  8af39a:	f1043703          	ld	a4,-240(s0)
  8af39e:	00f74563          	blt	a4,a5,8af3a8 <_ZNK4dnnl4impl3cpu4rv6417jit_uni_shuffle_t7executeERKNS0_10exec_ctx_tE+0x124>
  8af3a2:	f3843783          	ld	a5,-200(s0)
  8af3a6:	a0a9                	j	8af3f0 <_ZNK4dnnl4impl3cpu4rv6417jit_uni_shuffle_t7executeERKNS0_10exec_ctx_tE+0x16c>
  8af3a8:	4785                	li	a5,1
  8af3aa:	eef43423          	sd	a5,-280(s0)
  8af3ae:	f3843483          	ld	s1,-200(s0)
  8af3b2:	ee442783          	lw	a5,-284(s0)
  8af3b6:	f1043583          	ld	a1,-240(s0)
  8af3ba:	853e                	mv	a0,a5
  8af3bc:	ff7be097          	auipc	ra,0xff7be
  8af3c0:	fea080e7          	jalr	-22(ra) # 6d3a6 <_ZN4dnnl4impl5utils6div_upIllEENS1_9enable_ifIXaasrSt11is_integralIT_E5valueoosrS4_IT0_E5valuesrSt7is_enumIS7_E5valueENS1_16remove_referenceIS5_E4typeEE4typeES5_S7_>
  8af3c4:	87aa                	mv	a5,a0
  8af3c6:	85be                	mv	a1,a5
  8af3c8:	8526                	mv	a0,s1
  8af3ca:	ff7be097          	auipc	ra,0xff7be
  8af3ce:	fdc080e7          	jalr	-36(ra) # 6d3a6 <_ZN4dnnl4impl5utils6div_upIllEENS1_9enable_ifIXaasrSt11is_integralIT_E5valueoosrS4_IT0_E5valuesrSt7is_enumIS7_E5valueENS1_16remove_referenceIS5_E4typeEE4typeES5_S7_>
  8af3d2:	87aa                	mv	a5,a0
  8af3d4:	f6f43023          	sd	a5,-160(s0)
  8af3d8:	f6040713          	addi	a4,s0,-160
  8af3dc:	ee840793          	addi	a5,s0,-280
  8af3e0:	85ba                	mv	a1,a4
  8af3e2:	853e                	mv	a0,a5
  8af3e4:	ff819097          	auipc	ra,0xff819
  8af3e8:	792080e7          	jalr	1938(ra) # c8b76 <_ZN4dnnl4impl4nstl3maxIlEERKT_S5_S5_>
  8af3ec:	87aa                	mv	a5,a0
  8af3ee:	639c                	ld	a5,0(a5)
  8af3f0:	f0f43c23          	sd	a5,-232(s0)
  8af3f4:	f3843783          	ld	a5,-200(s0)
  8af3f8:	f1843583          	ld	a1,-232(s0)
  8af3fc:	853e                	mv	a0,a5
  8af3fe:	ff7be097          	auipc	ra,0xff7be
  8af402:	fa8080e7          	jalr	-88(ra) # 6d3a6 <_ZN4dnnl4impl5utils6div_upIllEENS1_9enable_ifIXaasrSt11is_integralIT_E5valueoosrS4_IT0_E5valuesrSt7is_enumIS7_E5valueENS1_16remove_referenceIS5_E4typeEE4typeES5_S7_>
  8af406:	f2a43023          	sd	a0,-224(s0)
  8af40a:	f2843803          	ld	a6,-216(s0)
  8af40e:	f3043503          	ld	a0,-208(s0)
  8af412:	f3843583          	ld	a1,-200(s0)
  8af416:	f4043603          	ld	a2,-192(s0)
  8af41a:	f4843683          	ld	a3,-184(s0)
  8af41e:	f5043703          	ld	a4,-176(s0)
  8af422:	f5843783          	ld	a5,-168(s0)
  8af426:	f7043023          	sd	a6,-160(s0)
  8af42a:	f6a43423          	sd	a0,-152(s0)
  8af42e:	f6b43823          	sd	a1,-144(s0)
  8af432:	f6c43c23          	sd	a2,-136(s0)
  8af436:	f8d43023          	sd	a3,-128(s0)
  8af43a:	f8e43423          	sd	a4,-120(s0)
  8af43e:	f8f43823          	sd	a5,-112(s0)
  8af442:	f1843783          	ld	a5,-232(s0)
  8af446:	f8f43c23          	sd	a5,-104(s0)
  8af44a:	ef043783          	ld	a5,-272(s0)
  8af44e:	faf43023          	sd	a5,-96(s0)
  8af452:	ef843783          	ld	a5,-264(s0)
  8af456:	faf43423          	sd	a5,-88(s0)
  8af45a:	ec843783          	ld	a5,-312(s0)
  8af45e:	faf43823          	sd	a5,-80(s0)
  8af462:	f6040713          	addi	a4,s0,-160
  8af466:	fb840793          	addi	a5,s0,-72
  8af46a:	85ba                	mv	a1,a4
  8af46c:	853e                	mv	a0,a5
  8af46e:	476000ef          	jal	8af8e4 <_ZNSt8functionIFvlllEEC1IZNK4dnnl4impl3cpu4rv6417jit_uni_shuffle_t7executeERKNS4_10exec_ctx_tEEUllllE_vEEOT_>
  8af472:	fb840793          	addi	a5,s0,-72
  8af476:	86be                	mv	a3,a5
  8af478:	f2043603          	ld	a2,-224(s0)
  8af47c:	f0843583          	ld	a1,-248(s0)
  8af480:	f0043503          	ld	a0,-256(s0)
  8af484:	c42ff0ef          	jal	8ae8c6 <_ZN4dnnl4implL11parallel_ndElllRKSt8functionIFvlllEE>
  8af488:	fb840793          	addi	a5,s0,-72
  8af48c:	853e                	mv	a0,a5
  8af48e:	ffbc8097          	auipc	ra,0xffbc8
  8af492:	4d8080e7          	jalr	1240(ra) # 477966 <_ZNSt8functionIFvlllEED1Ev>
  8af496:	4781                	li	a5,0
  8af498:	873e                	mv	a4,a5
  8af49a:	005eb797          	auipc	a5,0x5eb
  8af49e:	59e7b783          	ld	a5,1438(a5) # e9aa38 <__stack_chk_guard@GLIBC_2.27>
  8af4a2:	fd843683          	ld	a3,-40(s0)
  8af4a6:	639c                	ld	a5,0(a5)
  8af4a8:	8fb5                	xor	a5,a5,a3
  8af4aa:	4681                	li	a3,0
  8af4ac:	c3b1                	beqz	a5,8af4f0 <_ZNK4dnnl4impl3cpu4rv6417jit_uni_shuffle_t7executeERKNS0_10exec_ctx_tE+0x26c>
  8af4ae:	a82d                	j	8af4e8 <_ZNK4dnnl4impl3cpu4rv6417jit_uni_shuffle_t7executeERKNS0_10exec_ctx_tE+0x264>
  8af4b0:	84aa                	mv	s1,a0
  8af4b2:	fb840793          	addi	a5,s0,-72
  8af4b6:	853e                	mv	a0,a5
  8af4b8:	ffbc8097          	auipc	ra,0xffbc8
  8af4bc:	4ae080e7          	jalr	1198(ra) # 477966 <_ZNSt8functionIFvlllEED1Ev>
  8af4c0:	8726                	mv	a4,s1
  8af4c2:	005eb797          	auipc	a5,0x5eb
  8af4c6:	5767b783          	ld	a5,1398(a5) # e9aa38 <__stack_chk_guard@GLIBC_2.27>
  8af4ca:	fd843683          	ld	a3,-40(s0)
  8af4ce:	639c                	ld	a5,0(a5)
  8af4d0:	8fb5                	xor	a5,a5,a3
  8af4d2:	4681                	li	a3,0
  8af4d4:	c789                	beqz	a5,8af4de <_ZNK4dnnl4impl3cpu4rv6417jit_uni_shuffle_t7executeERKNS0_10exec_ctx_tE+0x25a>
  8af4d6:	ff7ab097          	auipc	ra,0xff7ab
  8af4da:	c6a080e7          	jalr	-918(ra) # 5a140 <__stack_chk_fail@plt>
  8af4de:	853a                	mv	a0,a4
  8af4e0:	ff7ab097          	auipc	ra,0xff7ab
  8af4e4:	e10080e7          	jalr	-496(ra) # 5a2f0 <_Unwind_Resume@plt>
  8af4e8:	ff7ab097          	auipc	ra,0xff7ab
  8af4ec:	c58080e7          	jalr	-936(ra) # 5a140 <__stack_chk_fail@plt>
  8af4f0:	853a                	mv	a0,a4
  8af4f2:	70f2                	ld	ra,312(sp)
  8af4f4:	7452                	ld	s0,304(sp)
  8af4f6:	74b2                	ld	s1,296(sp)
  8af4f8:	6131                	addi	sp,sp,320
  8af4fa:	8082                	ret

00000000008af4fc <_ZN4dnnl4impl3cpu4rv6417jit_uni_shuffle_tC1EPKNS3_4pd_tE>:
  8af4fc:	1101                	addi	sp,sp,-32
  8af4fe:	ec06                	sd	ra,24(sp)
  8af500:	e822                	sd	s0,16(sp)
  8af502:	1000                	addi	s0,sp,32
  8af504:	fea43423          	sd	a0,-24(s0)
  8af508:	feb43023          	sd	a1,-32(s0)
  8af50c:	fe843783          	ld	a5,-24(s0)
  8af510:	fe043583          	ld	a1,-32(s0)
  8af514:	853e                	mv	a0,a5
  8af516:	ffa64097          	auipc	ra,0xffa64
  8af51a:	f0c080e7          	jalr	-244(ra) # 313422 <_ZN4dnnl4impl11primitive_tC1EPKNS0_16primitive_desc_tE>
  8af51e:	005de717          	auipc	a4,0x5de
  8af522:	e7a70713          	addi	a4,a4,-390 # e8d398 <_ZTVN4dnnl4impl3cpu4rv6417jit_uni_shuffle_tE+0x10>
  8af526:	fe843783          	ld	a5,-24(s0)
  8af52a:	e398                	sd	a4,0(a5)
  8af52c:	fe843783          	ld	a5,-24(s0)
  8af530:	03878793          	addi	a5,a5,56
  8af534:	853e                	mv	a0,a5
  8af536:	55b030ef          	jal	8b3290 <_ZNSt10unique_ptrIN4dnnl4impl3cpu4rv6424jit_uni_shuffle_kernel_tESt14default_deleteIS4_EEC1IS6_vEEv>
  8af53a:	fe843783          	ld	a5,-24(s0)
  8af53e:	0407b023          	sd	zero,64(a5)
  8af542:	0001                	nop
  8af544:	60e2                	ld	ra,24(sp)
  8af546:	6442                	ld	s0,16(sp)
  8af548:	6105                	addi	sp,sp,32
  8af54a:	8082                	ret

00000000008af54c <_ZN4dnnl4impl3cpu4rv6417jit_uni_shuffle_tD1Ev>:
  8af54c:	1101                	addi	sp,sp,-32
  8af54e:	ec06                	sd	ra,24(sp)
  8af550:	e822                	sd	s0,16(sp)
  8af552:	1000                	addi	s0,sp,32
  8af554:	fea43423          	sd	a0,-24(s0)
  8af558:	005de717          	auipc	a4,0x5de
  8af55c:	e4070713          	addi	a4,a4,-448 # e8d398 <_ZTVN4dnnl4impl3cpu4rv6417jit_uni_shuffle_tE+0x10>
  8af560:	fe843783          	ld	a5,-24(s0)
  8af564:	e398                	sd	a4,0(a5)
  8af566:	fe843783          	ld	a5,-24(s0)
  8af56a:	63bc                	ld	a5,64(a5)
  8af56c:	853e                	mv	a0,a5
  8af56e:	ff9fc097          	auipc	ra,0xff9fc
  8af572:	5ce080e7          	jalr	1486(ra) # 2abb3c <_ZN4dnnl4impl4freeEPv>
  8af576:	fe843783          	ld	a5,-24(s0)
  8af57a:	03878793          	addi	a5,a5,56
  8af57e:	853e                	mv	a0,a5
  8af580:	539030ef          	jal	8b32b8 <_ZNSt10unique_ptrIN4dnnl4impl3cpu4rv6424jit_uni_shuffle_kernel_tESt14default_deleteIS4_EED1Ev>
  8af584:	fe843783          	ld	a5,-24(s0)
  8af588:	853e                	mv	a0,a5
  8af58a:	ffa66097          	auipc	ra,0xffa66
  8af58e:	b32080e7          	jalr	-1230(ra) # 3150bc <_ZN4dnnl4impl11primitive_tD1Ev>
  8af592:	0001                	nop
  8af594:	60e2                	ld	ra,24(sp)
  8af596:	6442                	ld	s0,16(sp)
  8af598:	6105                	addi	sp,sp,32
  8af59a:	8082                	ret

00000000008af59c <_ZN4dnnl4impl3cpu4rv6417jit_uni_shuffle_tD0Ev>:
  8af59c:	1101                	addi	sp,sp,-32
  8af59e:	ec06                	sd	ra,24(sp)
  8af5a0:	e822                	sd	s0,16(sp)
  8af5a2:	1000                	addi	s0,sp,32
  8af5a4:	fea43423          	sd	a0,-24(s0)
  8af5a8:	fe843503          	ld	a0,-24(s0)
  8af5ac:	fa1ff0ef          	jal	8af54c <_ZN4dnnl4impl3cpu4rv6417jit_uni_shuffle_tD1Ev>
  8af5b0:	fe843503          	ld	a0,-24(s0)
  8af5b4:	ff7ab097          	auipc	ra,0xff7ab
  8af5b8:	c2c080e7          	jalr	-980(ra) # 5a1e0 <_ZdlPv@plt>
  8af5bc:	60e2                	ld	ra,24(sp)
  8af5be:	6442                	ld	s0,16(sp)
  8af5c0:	6105                	addi	sp,sp,32
  8af5c2:	8082                	ret

00000000008af5c4 <_ZNSt8functionIFviiEEC1IZN4dnnl4implL11parallel_ndElRKS_IFvlEEEUliiE_vEEOT_>:
  8af5c4:	7179                	addi	sp,sp,-48
  8af5c6:	f406                	sd	ra,40(sp)
  8af5c8:	f022                	sd	s0,32(sp)
  8af5ca:	ec26                	sd	s1,24(sp)
  8af5cc:	1800                	addi	s0,sp,48
  8af5ce:	fca43c23          	sd	a0,-40(s0)
  8af5d2:	fcb43823          	sd	a1,-48(s0)
  8af5d6:	fd843783          	ld	a5,-40(s0)
  8af5da:	0007b023          	sd	zero,0(a5)
  8af5de:	0007b423          	sd	zero,8(a5)
  8af5e2:	0007b823          	sd	zero,16(a5)
  8af5e6:	fd843783          	ld	a5,-40(s0)
  8af5ea:	853e                	mv	a0,a5
  8af5ec:	ff7fd097          	auipc	ra,0xff7fd
  8af5f0:	7b4080e7          	jalr	1972(ra) # acda0 <_ZNSt14_Function_baseC1Ev>
  8af5f4:	fd843783          	ld	a5,-40(s0)
  8af5f8:	0007bc23          	sd	zero,24(a5)
  8af5fc:	fd043503          	ld	a0,-48(s0)
  8af600:	384000ef          	jal	8af984 <_ZNSt14_Function_base13_Base_managerIZN4dnnl4implL11parallel_ndElRKSt8functionIFvlEEEUliiE_E21_M_not_empty_functionIS8_EEbRKT_>
  8af604:	87aa                	mv	a5,a0
  8af606:	cba9                	beqz	a5,8af658 <_ZNSt8functionIFviiEEC1IZN4dnnl4implL11parallel_ndElRKS_IFvlEEEUliiE_vEEOT_+0x94>
  8af608:	fd843483          	ld	s1,-40(s0)
  8af60c:	fd043503          	ld	a0,-48(s0)
  8af610:	388000ef          	jal	8af998 <_ZSt7forwardIZN4dnnl4implL11parallel_ndElRKSt8functionIFvlEEEUliiE_EOT_RNSt16remove_referenceIS8_E4typeE>
  8af614:	87aa                	mv	a5,a0
  8af616:	85be                	mv	a1,a5
  8af618:	8526                	mv	a0,s1
  8af61a:	394000ef          	jal	8af9ae <_ZNSt14_Function_base13_Base_managerIZN4dnnl4implL11parallel_ndElRKSt8functionIFvlEEEUliiE_E15_M_init_functorIS8_EEvRSt9_Any_dataOT_>
  8af61e:	fd843783          	ld	a5,-40(s0)
  8af622:	00000717          	auipc	a4,0x0
  8af626:	3c070713          	addi	a4,a4,960 # 8af9e2 <_ZNSt17_Function_handlerIFviiEZN4dnnl4implL11parallel_ndElRKSt8functionIFvlEEEUliiE_E9_M_invokeERKSt9_Any_dataOiSD_>
  8af62a:	ef98                	sd	a4,24(a5)
  8af62c:	fd843783          	ld	a5,-40(s0)
  8af630:	00000717          	auipc	a4,0x0
  8af634:	40870713          	addi	a4,a4,1032 # 8afa38 <_ZNSt17_Function_handlerIFviiEZN4dnnl4implL11parallel_ndElRKSt8functionIFvlEEEUliiE_E10_M_managerERSt9_Any_dataRKSA_St18_Manager_operation>
  8af638:	eb98                	sd	a4,16(a5)
  8af63a:	a839                	j	8af658 <_ZNSt8functionIFviiEEC1IZN4dnnl4implL11parallel_ndElRKS_IFvlEEEUliiE_vEEOT_+0x94>
  8af63c:	84aa                	mv	s1,a0
  8af63e:	fd843783          	ld	a5,-40(s0)
  8af642:	853e                	mv	a0,a5
  8af644:	ff7fc097          	auipc	ra,0xff7fc
  8af648:	62c080e7          	jalr	1580(ra) # abc70 <_ZNSt14_Function_baseD1Ev>
  8af64c:	87a6                	mv	a5,s1
  8af64e:	853e                	mv	a0,a5
  8af650:	ff7ab097          	auipc	ra,0xff7ab
  8af654:	ca0080e7          	jalr	-864(ra) # 5a2f0 <_Unwind_Resume@plt>
  8af658:	0001                	nop
  8af65a:	70a2                	ld	ra,40(sp)
  8af65c:	7402                	ld	s0,32(sp)
  8af65e:	64e2                	ld	s1,24(sp)
  8af660:	6145                	addi	sp,sp,48
  8af662:	8082                	ret

00000000008af664 <_ZNSt8functionIFviiEEC1IZN4dnnl4implL11parallel_ndEllRKS_IFvllEEEUliiE_vEEOT_>:
  8af664:	7179                	addi	sp,sp,-48
  8af666:	f406                	sd	ra,40(sp)
  8af668:	f022                	sd	s0,32(sp)
  8af66a:	ec26                	sd	s1,24(sp)
  8af66c:	1800                	addi	s0,sp,48
  8af66e:	fca43c23          	sd	a0,-40(s0)
  8af672:	fcb43823          	sd	a1,-48(s0)
  8af676:	fd843783          	ld	a5,-40(s0)
  8af67a:	0007b023          	sd	zero,0(a5)
  8af67e:	0007b423          	sd	zero,8(a5)
  8af682:	0007b823          	sd	zero,16(a5)
  8af686:	fd843783          	ld	a5,-40(s0)
  8af68a:	853e                	mv	a0,a5
  8af68c:	ff7fd097          	auipc	ra,0xff7fd
  8af690:	714080e7          	jalr	1812(ra) # acda0 <_ZNSt14_Function_baseC1Ev>
  8af694:	fd843783          	ld	a5,-40(s0)
  8af698:	0007bc23          	sd	zero,24(a5)
  8af69c:	fd043503          	ld	a0,-48(s0)
  8af6a0:	412000ef          	jal	8afab2 <_ZNSt14_Function_base13_Base_managerIZN4dnnl4implL11parallel_ndEllRKSt8functionIFvllEEEUliiE_E21_M_not_empty_functionIS8_EEbRKT_>
  8af6a4:	87aa                	mv	a5,a0
  8af6a6:	cba9                	beqz	a5,8af6f8 <_ZNSt8functionIFviiEEC1IZN4dnnl4implL11parallel_ndEllRKS_IFvllEEEUliiE_vEEOT_+0x94>
  8af6a8:	fd843483          	ld	s1,-40(s0)
  8af6ac:	fd043503          	ld	a0,-48(s0)
  8af6b0:	416000ef          	jal	8afac6 <_ZSt7forwardIZN4dnnl4implL11parallel_ndEllRKSt8functionIFvllEEEUliiE_EOT_RNSt16remove_referenceIS8_E4typeE>
  8af6b4:	87aa                	mv	a5,a0
  8af6b6:	85be                	mv	a1,a5
  8af6b8:	8526                	mv	a0,s1
  8af6ba:	422000ef          	jal	8afadc <_ZNSt14_Function_base13_Base_managerIZN4dnnl4implL11parallel_ndEllRKSt8functionIFvllEEEUliiE_E15_M_init_functorIS8_EEvRSt9_Any_dataOT_>
  8af6be:	fd843783          	ld	a5,-40(s0)
  8af6c2:	00000717          	auipc	a4,0x0
  8af6c6:	44e70713          	addi	a4,a4,1102 # 8afb10 <_ZNSt17_Function_handlerIFviiEZN4dnnl4implL11parallel_ndEllRKSt8functionIFvllEEEUliiE_E9_M_invokeERKSt9_Any_dataOiSD_>
  8af6ca:	ef98                	sd	a4,24(a5)
  8af6cc:	fd843783          	ld	a5,-40(s0)
  8af6d0:	00000717          	auipc	a4,0x0
  8af6d4:	49670713          	addi	a4,a4,1174 # 8afb66 <_ZNSt17_Function_handlerIFviiEZN4dnnl4implL11parallel_ndEllRKSt8functionIFvllEEEUliiE_E10_M_managerERSt9_Any_dataRKSA_St18_Manager_operation>
  8af6d8:	eb98                	sd	a4,16(a5)
  8af6da:	a839                	j	8af6f8 <_ZNSt8functionIFviiEEC1IZN4dnnl4implL11parallel_ndEllRKS_IFvllEEEUliiE_vEEOT_+0x94>
  8af6dc:	84aa                	mv	s1,a0
  8af6de:	fd843783          	ld	a5,-40(s0)
  8af6e2:	853e                	mv	a0,a5
  8af6e4:	ff7fc097          	auipc	ra,0xff7fc
  8af6e8:	58c080e7          	jalr	1420(ra) # abc70 <_ZNSt14_Function_baseD1Ev>
  8af6ec:	87a6                	mv	a5,s1
  8af6ee:	853e                	mv	a0,a5
  8af6f0:	ff7ab097          	auipc	ra,0xff7ab
  8af6f4:	c00080e7          	jalr	-1024(ra) # 5a2f0 <_Unwind_Resume@plt>
  8af6f8:	0001                	nop
  8af6fa:	70a2                	ld	ra,40(sp)
  8af6fc:	7402                	ld	s0,32(sp)
  8af6fe:	64e2                	ld	s1,24(sp)
  8af700:	6145                	addi	sp,sp,48
  8af702:	8082                	ret

00000000008af704 <_ZNSt8functionIFviiEEC1IZN4dnnl4implL11parallel_ndElllRKS_IFvlllEEEUliiE_vEEOT_>:
  8af704:	7179                	addi	sp,sp,-48
  8af706:	f406                	sd	ra,40(sp)
  8af708:	f022                	sd	s0,32(sp)
  8af70a:	ec26                	sd	s1,24(sp)
  8af70c:	1800                	addi	s0,sp,48
  8af70e:	fca43c23          	sd	a0,-40(s0)
  8af712:	fcb43823          	sd	a1,-48(s0)
  8af716:	fd843783          	ld	a5,-40(s0)
  8af71a:	0007b023          	sd	zero,0(a5)
  8af71e:	0007b423          	sd	zero,8(a5)
  8af722:	0007b823          	sd	zero,16(a5)
  8af726:	fd843783          	ld	a5,-40(s0)
  8af72a:	853e                	mv	a0,a5
  8af72c:	ff7fd097          	auipc	ra,0xff7fd
  8af730:	674080e7          	jalr	1652(ra) # acda0 <_ZNSt14_Function_baseC1Ev>
  8af734:	fd843783          	ld	a5,-40(s0)
  8af738:	0007bc23          	sd	zero,24(a5)
  8af73c:	fd043503          	ld	a0,-48(s0)
  8af740:	4a0000ef          	jal	8afbe0 <_ZNSt14_Function_base13_Base_managerIZN4dnnl4implL11parallel_ndElllRKSt8functionIFvlllEEEUliiE_E21_M_not_empty_functionIS8_EEbRKT_>
  8af744:	87aa                	mv	a5,a0
  8af746:	cba9                	beqz	a5,8af798 <_ZNSt8functionIFviiEEC1IZN4dnnl4implL11parallel_ndElllRKS_IFvlllEEEUliiE_vEEOT_+0x94>
  8af748:	fd843483          	ld	s1,-40(s0)
  8af74c:	fd043503          	ld	a0,-48(s0)
  8af750:	4a4000ef          	jal	8afbf4 <_ZSt7forwardIZN4dnnl4implL11parallel_ndElllRKSt8functionIFvlllEEEUliiE_EOT_RNSt16remove_referenceIS8_E4typeE>
  8af754:	87aa                	mv	a5,a0
  8af756:	85be                	mv	a1,a5
  8af758:	8526                	mv	a0,s1
  8af75a:	4b0000ef          	jal	8afc0a <_ZNSt14_Function_base13_Base_managerIZN4dnnl4implL11parallel_ndElllRKSt8functionIFvlllEEEUliiE_E15_M_init_functorIS8_EEvRSt9_Any_dataOT_>
  8af75e:	fd843783          	ld	a5,-40(s0)
  8af762:	00000717          	auipc	a4,0x0
  8af766:	4dc70713          	addi	a4,a4,1244 # 8afc3e <_ZNSt17_Function_handlerIFviiEZN4dnnl4implL11parallel_ndElllRKSt8functionIFvlllEEEUliiE_E9_M_invokeERKSt9_Any_dataOiSD_>
  8af76a:	ef98                	sd	a4,24(a5)
  8af76c:	fd843783          	ld	a5,-40(s0)
  8af770:	00000717          	auipc	a4,0x0
  8af774:	52470713          	addi	a4,a4,1316 # 8afc94 <_ZNSt17_Function_handlerIFviiEZN4dnnl4implL11parallel_ndElllRKSt8functionIFvlllEEEUliiE_E10_M_managerERSt9_Any_dataRKSA_St18_Manager_operation>
  8af778:	eb98                	sd	a4,16(a5)
  8af77a:	a839                	j	8af798 <_ZNSt8functionIFviiEEC1IZN4dnnl4implL11parallel_ndElllRKS_IFvlllEEEUliiE_vEEOT_+0x94>
  8af77c:	84aa                	mv	s1,a0
  8af77e:	fd843783          	ld	a5,-40(s0)
  8af782:	853e                	mv	a0,a5
  8af784:	ff7fc097          	auipc	ra,0xff7fc
  8af788:	4ec080e7          	jalr	1260(ra) # abc70 <_ZNSt14_Function_baseD1Ev>
  8af78c:	87a6                	mv	a5,s1
  8af78e:	853e                	mv	a0,a5
  8af790:	ff7ab097          	auipc	ra,0xff7ab
  8af794:	b60080e7          	jalr	-1184(ra) # 5a2f0 <_Unwind_Resume@plt>
  8af798:	0001                	nop
  8af79a:	70a2                	ld	ra,40(sp)
  8af79c:	7402                	ld	s0,32(sp)
  8af79e:	64e2                	ld	s1,24(sp)
  8af7a0:	6145                	addi	sp,sp,48
  8af7a2:	8082                	ret
