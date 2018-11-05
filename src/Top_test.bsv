/*-
 * Copyright (c) 2018 Alexandre Joannou
 * All rights reserved.
 *
 * This software was developed by SRI International and the University of
 * Cambridge Computer Laboratory (Department of Computer Science and
 * Technology) under DARPA contract HR0011-18-C-0016 ("ECATS"), as part of the
 * DARPA SSITH research programme.
 *
 * @BERI_LICENSE_HEADER_START@
 *
 * Licensed to BERI Open Systems C.I.C. (BERI) under one or more contributor
 * license agreements.  See the NOTICE file distributed with this work for
 * additional information regarding copyright ownership.  BERI licenses this
 * file to you under the BERI Hardware-Software License, Version 1.0 (the
 * "License"); you may not use this file except in compliance with the
 * License.  You may obtain a copy of the License at:
 *
 *   http://www.beri-open-systems.org/legal/license-1-0.txt
 *
 * Unless required by applicable law or agreed to in writing, Work distributed
 * under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
 * CONDITIONS OF ANY KIND, either express or implied.  See the License for the
 * specific language governing permissions and limitations under the License.
 *
 * @BERI_LICENSE_HEADER_END@
 */

import AxiDefines :: *;
import       PISM :: *;

module top (Empty);
  let pism <- mkAXI_PISM;
  rule axiRdSlave_arADDR; pism.axiRdSlave.arADDR(?); endrule
  rule axiRdSlave_arBURST; pism.axiRdSlave.arBURST(?); endrule
  rule axiRdSlave_arCACHE; pism.axiRdSlave.arCACHE(?); endrule
  rule axiRdSlave_arID; pism.axiRdSlave.arID(?); endrule
  rule axiRdSlave_arLEN; pism.axiRdSlave.arLEN(?); endrule
  rule axiRdSlave_arLOCK; pism.axiRdSlave.arLOCK(?); endrule
  rule axiRdSlave_arPROT; pism.axiRdSlave.arPROT(?); endrule
  rule axiRdSlave_arSIZE; pism.axiRdSlave.arSIZE(?); endrule
  rule axiRdSlave_arVALID; pism.axiRdSlave.arVALID(?); endrule
  rule axiRdSlave_rREADY; pism.axiRdSlave.rREADY(?); endrule
  rule axiWrSlave_awADDR; pism.axiWrSlave.awADDR(?); endrule
  rule axiWrSlave_awBURST; pism.axiWrSlave.awBURST(?); endrule
  rule axiWrSlave_awCACHE; pism.axiWrSlave.awCACHE(?); endrule
  rule axiWrSlave_awID; pism.axiWrSlave.awID(?); endrule
  rule axiWrSlave_awLEN; pism.axiWrSlave.awLEN(?); endrule
  rule axiWrSlave_awLOCK; pism.axiWrSlave.awLOCK(?); endrule
  rule axiWrSlave_awPROT; pism.axiWrSlave.awPROT(?); endrule
  rule axiWrSlave_awSIZE; pism.axiWrSlave.awSIZE(?); endrule
  rule axiWrSlave_awVALID; pism.axiWrSlave.awVALID(?); endrule
  rule axiWrSlave_bREADY; pism.axiWrSlave.bREADY(?); endrule
  rule axiWrSlave_wDATA; pism.axiWrSlave.wDATA(?); endrule
  rule axiWrSlave_wID; pism.axiWrSlave.wID(?); endrule
  rule axiWrSlave_wLAST; pism.axiWrSlave.wLAST(?); endrule
  rule axiWrSlave_wSTRB; pism.axiWrSlave.wSTRB(?); endrule
  rule axiWrSlave_wVALID; pism.axiWrSlave.wVALID(?); endrule
endmodule
