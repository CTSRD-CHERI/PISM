#-
# Copyright (c) 2018 Alexandre Joannou
# All rights reserved.
#
# This software was developed by SRI International and the University of
# Cambridge Computer Laboratory (Department of Computer Science and
# Technology) under DARPA contract HR0011-18-C-0016 ("ECATS"), as part of the
# DARPA SSITH research programme.
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

BSC = bsc

SRCDIR = src
PISMDEVDIR = $(SRCDIR)/pismdev
BSVPATH = +:$(SRCDIR):%/Libraries/TLM3:%/Libraries/Axi

BSCFLAGS = -p $(BSVPATH)

# generated files directories
BUILDDIR = build
BDIR = $(BUILDDIR)/bdir
SIMDIR = $(BUILDDIR)/simdir

OUTPUTDIR = output

BSCFLAGS += -bdir $(BDIR)

BSCFLAGS += -show-schedule
BSCFLAGS += -sched-dot
BSCFLAGS += -show-range-conflict
#BSCFLAGS += -show-rule-rel \* \*
#BSCFLAGS += -steps-warn-interval n

# Bluespec is not compatible with gcc > 4.9
# This is actually problematic when using $test$plusargs
CC = gcc-4.8
CXX = g++-4.8

all: axi_pism

pism: $(PISMDEVDIR)/libpism.so

link-so: $(PISMDEVDIR)/libpism.so
	ln -s $(PISMDEVDIR)/libpism.so
	ln -s $(PISMDEVDIR)/dram.so
	ln -s $(PISMDEVDIR)/ethercap.so
	ln -s $(PISMDEVDIR)/uart.so
	ln -s $(PISMDEVDIR)/fb.so
	ln -s $(PISMDEVDIR)/sdcard.so
	ln -s $(PISMDEVDIR)/virtio_block.so

$(PISMDEVDIR)/libpism.so:
	$(MAKE) -C $(PISMDEVDIR)

axi_pism: $(SRCDIR)/Top_test.bsv link-so
	mkdir -p $(OUTPUTDIR)/$@-info $(BDIR) $(SIMDIR)
	$(BSC) -info-dir $(OUTPUTDIR)/$@-info -simdir $(SIMDIR) $(BSCFLAGS) -sim -g top -u $<
	CC=$(CC) CXX=$(CXX) $(BSC) -simdir $(SIMDIR) $(BSCFLAGS) -L . -l pism -sim -e top -o $(OUTPUTDIR)/$@

.PHONY: clean clean-libpism.so mrproper

clean-libpism.so:
	$(MAKE) -C $(PISMDEVDIR) clean
	rm -f libpism.so
	rm -f dram.so
	rm -f ethercap.so
	rm -f uart.so
	rm -f fb.so
	rm -f sdcard.so
	rm -f virtio_block.so

clean: clean-libpism.so
	rm -f -r $(BUILDDIR)

mrproper: clean
	rm -f -r $(OUTPUTDIR)
