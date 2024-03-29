#-
# Copyright (c) 2011-2012 Philip Paeps
# Copyright (c) 2011 Jonathan Anderson
# Copyright (c) 2011 Jonathan Woodruff
# Copyright (c) 2012-2014 Robert N. M. Watson
# Copyright (c) 2012-2014 Simon W. Moore
# Copyright (c) 2013 Philip Withnall
# Copyright (c) 2013 Bjoern A. Zeeb
# Copyright (c) 2013 Robert M. Norton
# Copyright (c) 2013 Colin Rothwell
# Copyright (c) 2018 Alexandre Joannou
# All rights reserved.
#
# This software was developed by SRI International and the University of
# Cambridge Computer Laboratory under DARPA/AFRL contract FA8750-10-C-0237
# ("CTSRD"), as part of the DARPA CRASH research programme.
#
# @BERI_LICENSE_HEADER_START@
#
# Licensed to BERI Open Systems C.I.C. (BERI) under one or more contributor
# license agreements.  See the NOTICE file distributed with this work for
# additional information regarding copyright ownership.  BERI licenses this
# file to you under the BERI Hardware-Software License, Version 1.0 (the
# "License"); you may not use this file except in compliance with the
# License.  You may obtain a copy of the License at:
#
#   http://www.beri-open-systems.org/legal/license-1-0.txt
#
# Unless required by applicable law or agreed to in writing, Work distributed
# under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
# CONDITIONS OF ANY KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations under the License.
#
# @BERI_LICENSE_HEADER_END@
#

# Build peripherals as shared objects

VPATH=.:dram:uart:sdcard:virtio:ether:framebuffer:debug_stream

TARGETS=libpism.so				\
	dram.so					\
	ethercap.so				\
	fb.so					\
	sdcard.so				\
	virtio_block.so				\
	uart.so					\
	chericonf				\
	pismtest

objs=						\
	dram.o					\
	ethercap.o				\
	sdcard.o				\
	virtio_block.o				\
	virtio.o				\
	uart.o					\
	fb.o					\
	chericonf.o				\
	config.o				\
	pism.o					\
	pism_device.o				\
	scan.o

all: $(TARGETS)
.PHONY: all pism

CFLAGS = -fPIC -g -Wall -I.. -I. -Wl,--no-as-needed
MODULE_CFLAGS= -fPIC -g -Wall -L . -shared
YACC = bison
YFLAGS = -dy

chericonf: chericonf.o config.o scan.o pism_device.o pism.o
	$(CC) $(CFLAGS) -ldl -o $@ $^ 

pismtest: pismtest.c
	$(CC) $(CFLAGS) -o $@ $^ -ldl -L . -lpism 

test: pismtest
	LD_LIBRARY_PATH=. ./pismtest

pism: $(TARGETS)

libpism.so: pism.o config.o scan.o pism_device.o
	$(CC) $(CFLAGS) -shared -o $@ $^

config.o: pism.h
pism.o: config.o cheri.h pism.h
scan.o: config.o

dram.so: dram.o libpism.so
	$(CC) $(MODULE_CFLAGS) -o $@ $^ -lpism

ethercap.so: ethercap.o libpism.so
	$(CC) $(MODULE_CFLAGS) -o $@ $^ -lpism

fb.so: fb.o libpism.so
	$(CC) $(MODULE_CFLAGS) -o $@ $^ -lSDL -lpism

sdcard.so: sdcard.o libpism.so
	$(CC) $(MODULE_CFLAGS) -o $@ $^ -lpism

virtio_block.so: virtio_block.o virtio.o libpism.so
	$(CC) $(MODULE_CFLAGS) -o $@ $^ -lbsd -lpism

uart.so: uart.o libpism.so
	$(CC) $(MODULE_CFLAGS) -o $@ $^ -lpism

$(objs): pism.h
EtherCAP/ethercap.o: cheri.h

clean:
	-rm -f $(TARGETS) y.tab.h $(objs)
	-rm -rf qsys_ip/Compositor
.PHONY: clean test
