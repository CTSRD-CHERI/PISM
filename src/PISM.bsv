/*-
 * Copyright (c) 2013 SRI International
 * Copyright (c) 2013-2014 Colin Rothwell
 * Copyright (c) 2013 Jonathan Woodruff
 * Copyright (c) 2011 Simon W. Moore
 * Copyright (c) 2014-2018 Alexandre Joannou
 * Copyright (c) 2015 Paul J. Fox
 * All rights reserved.
 *
 * This software was developed by SRI International and the University of
 * Cambridge Computer Laboratory under DARPA/AFRL contract FA8750-10-C-0237
 * ("CTSRD"), as part of the DARPA CRASH research programme.
 *
 * This software was developed by SRI International and the University of
 * Cambridge Computer Laboratory under DARPA/AFRL contract FA8750-11-C-0249
 * ("MRC2"), as part of the DARPA MRC research programme.
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
 *
 ******************************************************************************
 * Description
 * 
 * Provides a set of wrappers and data structures for the PISM C simulation
 * models.
 ******************************************************************************/

package PISM;

export AXI_PISM(..);
export mkAXI_PISM;

import DefaultValue::*;

typedef enum {
  PISM_BUS_MEMORY,
  PISM_BUS_PERIPHERAL,
  PISM_BUS_TRACE
} PismBus deriving(Bits, Eq, FShow);

typedef struct {
  Bit#(64)   addr;    // 8 bytes
  Bit#(256)  data;    // 32 bytes
  Bit#(32)   byteenable;  // 4 bytes
  Bit#(8)    write; // 1 byte, 1==write, 0==read
  Bit#(152)  pad1;    // 19 bytes
} PismData deriving (Bits, Eq, Bounded);

PismData pdef = PismData {
  addr: 64'h0,
  data: 256'h0,
  byteenable: 32'hffffffff,
  write: 8'h0,
  pad1: 152'h0
};

instance DefaultValue#(PismData);
    function PismData defaultValue();
        return pdef;
    endfunction
endinstance

instance FShow#(PismData);
    function Fmt fshow(PismData pd);
        Bit#(1) onebwrite = truncate(pd.write);
        return $format("< PISMData addr: 0x%x, data: 0x%x, byte enable: 0x%x,",
            pd.addr, pd.data, pd.byteenable, "write: %b >", onebwrite);
    endfunction
endinstance

typedef enum {
    DEBUG_STREAM_0,
    DEBUG_STREAM_1
} DebugStream deriving (Bits, Eq, FShow);

// Import simple character input
import "BDPI" function ActionValue#(Bit#(32))  c_getchar();
// Import the interfaces of the PISM Bus for C peripherals
import "BDPI" function ActionValue#(Bool)      pism_init(PismBus bus);
import "BDPI" function Action                  pism_cycle_tick(PismBus bus);
import "BDPI" function Bit#(32)                pism_interrupt_get(PismBus bus);
import "BDPI" function Bool                    pism_request_ready(PismBus bus, PismData req);
import "BDPI" function Action                  pism_request_put(PismBus bus, PismData req);
import "BDPI" function Bool                    pism_response_ready(PismBus bus);
import "BDPI" function ActionValue#(Bit#(512)) pism_response_get(PismBus bus);
import "BDPI" function Bool      	       pism_addr_valid(PismBus bus, PismData req);
// Import the interfaces of a streaming character interface in C.
import "BDPI" function ActionValue#(Bool)      debug_stream_init(DebugStream ds);
import "BDPI" function Bool                    debug_stream_sink_ready(DebugStream ds);
import "BDPI" function Action                  debug_stream_sink_put(DebugStream ds, Bit#(8) char);
import "BDPI" function Bool                    debug_stream_source_ready(DebugStream ds);
import "BDPI" function ActionValue#(Bit#(8))   debug_stream_source_get(DebugStream ds);

// Bluespec PISM wrapper
////////////////////////////////////////////////////////////////////////////////

import        FIFOF :: *;
import SpecialFIFOs :: *;
import       Vector :: *;
import       GetPut :: *;
import       Assert :: *;
import          Axi :: *;
import         TLM3 :: *;
import  Connectable :: *;

import        Debug :: *;
import      Library :: *;
import     PutMerge :: *;

`define DATA_sz 128
`define ADDR_sz  40
`define ID_sz     8
// TLM parms, width of fields: id, addr, data, burst, user
`define TLM_PRM `ID_sz, `ADDR_sz, `DATA_sz, 4, 0
`define TLM_RR TLMRequest#(`TLM_PRM), TLMResponse#(`TLM_PRM)

interface AXI_PISM;
  interface AxiRdSlave#(`TLM_PRM) axiRdSlave;
  interface AxiWrSlave#(`TLM_PRM) axiWrSlave;
  method Bit#(32) peekIRQs;
endinterface

(* synthesize *)
module mkAXI_PISM(AXI_PISM);

  // PISM module instance
  TLMReadWriteRecvIFC#(`TLM_RR) pismMemory <- mkPISMTLM(PISM_BUS_MEMORY);

  // wire up PISM module
  //////////////////////////////////////////////////////////////////////////////

  function pismAddrMatch(bus, addr);
    PismData req = defaultValue();
    req.addr = zeroExtend(addr);
    return pism_addr_valid(bus, req);
  endfunction

  let matchMemAddr = pismAddrMatch(PISM_BUS_MEMORY);

  AxiRdSlaveXActorIFC#(`TLM_RR, `TLM_PRM) pismMemoryRdXActor <-
    mkAxiRdSlave(True, matchMemAddr);
  mkConnection(pismMemory.read, pismMemoryRdXActor.tlm);

  AxiWrSlaveXActorIFC#(`TLM_RR, `TLM_PRM) pismMemoryWrXActor <-
    mkAxiWrSlave(True, matchMemAddr);
  mkConnection(pismMemory.write, pismMemoryWrXActor.tlm);

  // setup + tick PISM module
  //////////////////////////////////////////////////////////////////////////////

  Reg#(Bool) pismMemorySetup <- mkReg(False);

  rule setupPISMMemory (!pismMemorySetup);
      Bool pismInitSuccess <- pism_init(PISM_BUS_MEMORY);
      pismMemorySetup <= pismInitSuccess;
  endrule

  (* fire_when_enabled, no_implicit_conditions *)
  rule tickPISM;
      pism_cycle_tick(PISM_BUS_MEMORY);
  endrule

  // interface
  //////////////////////////////////////////////////////////////////////////////

  interface axiRdSlave = pismMemoryRdXActor.fabric.bus;
  interface axiWrSlave = pismMemoryWrXActor.fabric.bus;
  method peekIRQs = pism_interrupt_get(PISM_BUS_MEMORY);

endmodule

typedef enum {
  Read,
  Write
} RequestType deriving (Bits, Eq, FShow);

typedef enum {
  Error,
  PISM
} ResponseSource deriving (Bits, Eq, FShow);

Bit#(128) beFor8Bit    = 128'h1;
Bit#(128) beFor16Bit   = (beFor8Bit << 1) | beFor8Bit;
Bit#(128) beFor32Bit   = (beFor16Bit << 2) | beFor16Bit;
Bit#(128) beFor64Bit   = (beFor32Bit << 4) | beFor32Bit;
Bit#(128) beFor128Bit  = (beFor64Bit << 8) | beFor64Bit;
Bit#(128) beFor256Bit  = (beFor128Bit << 16) | beFor128Bit;
Bit#(128) beFor512Bit  = (beFor256Bit << 32) | beFor256Bit;
Bit#(128) beFor1024Bit = (beFor512Bit << 64) | beFor512Bit;

function Bit#(128) beForBurstSize(TLMBSize burstSize);
    return (case (burstSize)
        BITS8:    beFor8Bit;
        BITS16:   beFor16Bit;
        BITS32:   beFor32Bit;
        BITS64:   beFor64Bit;
        BITS128:  beFor128Bit;
        BITS256:  beFor256Bit;
        BITS512:  beFor512Bit;
        BITS1024: beFor1024Bit;
    endcase);
endfunction

function TLMResponse#(`TLM_PRM) tlmResponseFromRequestDescriptor(
        RequestDescriptor#(`TLM_PRM) req);
    return (TLMResponse {
        command: req.command,
        data: defaultValue(),
        status: SUCCESS,
        user: 0,
        prty: req.prty,
        transaction_id: req.transaction_id,
        is_last: True
    });
endfunction

function TLMResponse#(`TLM_PRM) tlmResponseFromRequest(
        TLMRequest#(`TLM_PRM) req);
    case (req) matches
        tagged Descriptor .desc:
            return tlmResponseFromRequestDescriptor(desc);
        tagged Data .data: begin
            TLMResponse#(`TLM_PRM) resp = defaultValue();
            resp.command = WRITE;
            resp.transaction_id = data.transaction_id;
            resp.is_last = True;
            return resp;
        end
    endcase
endfunction

function Tuple3#(TLMAddr#(`TLM_PRM), Bit#(32), Bit#(5))
  byteEnFromBurstSize(TLMAddr#(`TLM_PRM) inAddr,
                      TLMBSize burstSize);

  Bit#(32) unshiftedBE = truncate(beForBurstSize(burstSize));
  TLMAddr#(`TLM_PRM) lineAddressMask = '1 << 5;
  TLMAddr#(`TLM_PRM) lineAddress = inAddr & lineAddressMask;
  Bit#(5) partOffset = truncate(inAddr & ~lineAddressMask);
  Bit#(32) shiftedBE = unshiftedBE << partOffset;
  // Force alignment of offset to 128b which will be used for write data and byte enables.
  partOffset[3:0] = 0;
  return tuple3(lineAddress, shiftedBE, partOffset);

endfunction

typedef union tagged {
  success Success;
  Action Fail;
} MightFail#(type success);

typedef 4 MaxNoOfFlits;
typedef UInt#(TLog#(MaxNoOfFlits)) Flit;
// PISM doesn't have split read/write busses, but TLM does. This uses FIFOs to
// give a limited ability for both methods to be called in the same cycle, but
// obviously can't provide the full throughput.
module mkPISMTLM#(PismBus bus)(TLMReadWriteRecvIFC#(`TLM_RR));

  FIFOF#(TLMRequest#(`TLM_PRM)) tlmRequests <- mkBypassFIFOF();
  PutMerge#(TLMRequest#(`TLM_PRM)) requestMerge <- mkPutMerge(toPut(tlmRequests));
  FIFOF#(PismData) pismRequests <- mkBypassFIFOF();
  
  // Data from PISM not attached to RESP
  FIFOF#(TLMResponse#(`TLM_PRM)) incompleteResps <- mkBypassFIFOF();
  // Ready to return
  FIFOF#(TLMResponse#(`TLM_PRM)) completeResps <- mkSizedFIFOF(16);
  
  Reg#(Flit) flit <- mkReg(0); // 4 is the maximum number of flits supported
  
  function MightFail#(PismData) translateReq(TLMRequest#(`TLM_PRM) tlmReq);
    if (tlmReq matches tagged Descriptor .tlmDesc) begin
      if (tlmDesc.command == UNKNOWN) begin
        let msg = "TLM Command fed to PISM is unknown.";
        return tagged Fail debug2("simaxi", $display(msg));
      end
      else if (tlmDesc.b_size == BITS512 ||
               tlmDesc.b_size == BITS1024) begin
        let msg = "Attempting to read more than a line from PISM.";
        return tagged Fail debug2("simaxi", $display(msg));
      end
      else begin
        match {.calcAddr, .calcBE, .byteShift} =
          byteEnFromBurstSize(tlmDesc.addr, tlmDesc.b_size);
        Bit#(32) byteEnable = (case (tlmDesc.byte_enable) matches
          tagged Specify .be: return zeroExtend(be)<<byteShift;
          tagged Calculate:   return calcBE;
        endcase);
        let isWrite = (tlmDesc.command == WRITE);
        PismData ret = PismData {
          addr: zeroExtend(calcAddr),
          data: zeroExtend(tlmDesc.data),
          byteenable: zeroExtend(byteEnable),
          write: zeroExtend(pack(isWrite)),
          pad1: ?
        };
        ret.data = ret.data << {byteShift, 3'b0};
        return tagged Success ret;
      end
    end
    else begin // Not a descriptor
      let msg = "Can't burst read/write PISM";
      return tagged Fail debug2("simaxi", $display(msg));
    end
  endfunction
  
  rule translateReqAndPrepareResp;
    let req  = tlmRequests.first();
    debug2("simaxi", $display("Input request: ", fshow(req)));
    let resp = tlmResponseFromRequest(req);
    if (req matches tagged Descriptor .td) begin
      debug2("simaxi", $display("burst length:%x", td.b_length));
      let newTd = td;
      Bit#(TLog#(TDiv#(`DATA_sz, 8))) space = 0;
      newTd.addr = td.addr + zeroExtend({pack(flit),space});
      // Stash shift amount for read response.
      resp.data = zeroExtend({newTd.addr[4],1'b0});
      req = tagged Descriptor newTd;
    end
    let fail = True;
    case (translateReq(req)) matches
      tagged Success .pr: begin
        if (pism_addr_valid(bus, pr)) begin
          PismData prs = pr;
          debug2("simaxi", $displayh(fshow(prs), prs.addr));
          /*
          Bit#(5) byteOffset = truncate(prs.addr);
          prs.addr = prs.addr & signExtend(6'h20); // Force alignment for PISM.
          // Calculate rotate amount for request or response data and stash it in data field.
          Bit#(2) doubleWordOffset = truncateLSB(byteOffset);
          
          // Shift Data
          Vector#(4, Bit#(64)) dataVec = unpack(prs.data);
          Vector#(4, Bit#(64)) newDataVec = ?;
          for (Integer i=0; i<4; i=i+1) newDataVec[doubleWordOffset+fromInteger(i)] = dataVec[i];
          prs.data = pack(newDataVec);
          // Shift ByteEnable
          Vector#(4, Bit#(8)) beVec = unpack(prs.byteenable);
          Vector#(4, Bit#(8)) newBeVec = ?;
          for (Integer i=0; i<4; i=i+1) newBeVec[doubleWordOffset+fromInteger(i)] = beVec[i];
          prs.byteenable = pack(newBeVec);*/
          pismRequests.enq(prs);
          //debug2("simaxi", $display("doubleWordOffset=%d ", doubleWordOffset, fshow(prs), prs.addr));
          Flit burstSize = 0;
          if (req matches tagged Descriptor .td)
            burstSize = truncate(td.b_length);
          if (flit == burstSize) begin
            debug2("simaxi", $display("last flit==%x burstSize==%x", flit, burstSize));
            tlmRequests.deq();
            flit <= 0;
            resp.is_last = True;
          end else begin
            debug2("simaxi", $display("next flit==%x burstSize==%x", flit, burstSize));
            flit <= flit + 1;
            resp.is_last = False;
          end
          fail = False;
        end
        else begin
          debug2("simaxi", $write("Invalid PISM Address for "));
          debug2("simaxi", $displayh(fshow(bus), pr.addr));
          fail = True;
          tlmRequests.deq();
        end
      end
      tagged Fail .act: begin
        act();
        fail = True;
        tlmRequests.deq();
      end
      default: begin
        tlmRequests.deq();
      end
    endcase
    if (fail) begin
      debug2("simaxi", $display("Bad request: ", fshow(req)));
      resp.status = ERROR;
    end
    incompleteResps.enq(resp);
  endrule
  
  rule putReq (pismRequests.notEmpty());
    if (pism_request_ready(bus, pismRequests.first)) begin
      let pr <- popFIFOF(pismRequests);
      debug2("simaxi", $display("%t: Putting to PISM", $time, fshow(pr)));
      pism_request_put(bus, pr);
    end
  endrule
  
  rule completeErrorResp (incompleteResps.first.status == ERROR);
    let resp <- popFIFOF(incompleteResps);
    completeResps.enq(resp);
  endrule
  
  rule completeWriteResp (
    incompleteResps.first.status == SUCCESS &&
    incompleteResps.first.command == WRITE
  );
    let resp <- popFIFOF(incompleteResps);
    completeResps.enq(resp);
  endrule
  
  rule completeReadResp (
    incompleteResps.first.status == SUCCESS &&
    incompleteResps.first.command == READ &&
    pism_response_ready(bus)
  );
    Bit#(512) pismBitResp <- pism_response_get(bus);
    PismData pismResp = unpack(pismBitResp);
    let resp <- popFIFOF(incompleteResps);
    Vector#(4, Bit#(64)) dataVec = unpack(pismResp.data);
    // Rotate the array so that the target words are at the bottom.
    Bit#(2) idx = unpack(truncate(resp.data));
    for (Integer i=0; i<4; i=i+1) dataVec[i] = dataVec[idx+fromInteger(i)];
    resp.data = truncate(pack(dataVec));
    debug2("simaxi", $display("%t: Completing PISM read response: Rotate amount = %x ", $time,
      idx, fshow(dataVec), fshow(pismResp)));
    debug2("simaxi", $display("%t: Completing PISM read response: ", $time,
      fshow(resp)));
    completeResps.enq(resp);
  endrule
  
  rule completeUnknownResp (
    (incompleteResps.first.status == SUCCESS &&
     incompleteResps.first.command == UNKNOWN) ||
    (incompleteResps.first.status != SUCCESS &&
     incompleteResps.first.status != ERROR)
  );
    let msg = "Trying to return unknown response! ";
    dynamicAssert(False, msg);
    let resp <- popFIFOF(incompleteResps);
    debug2("simaxi", $display("!!! ", msg, resp));
  endrule
  
  interface TLMRecvIFC read;
    interface Put rx = toPut(requestMerge.left);
    interface Get tx;
      method ActionValue#(TLMResponse#(`TLM_PRM)) get
              if (completeResps.first.command == READ);
        let resp <- popFIFOF(completeResps);
        debug2("simaxi", $display("%t: Returning complete PISM read resp: ",
          $time, fshow(resp)));
        return resp;
      endmethod
    endinterface
  endinterface
  
  interface TLMRecvIFC write;
    interface Put rx = toPut(requestMerge.right);
    interface Get tx;
      method ActionValue#(TLMResponse#(`TLM_PRM)) get
            if (completeResps.first.command == WRITE);
        let resp <- popFIFOF(completeResps);
        debug2("simaxi", $display("%t: Returning complete PISM write resp: ",
          $time, fshow(resp)));
        return resp;
      endmethod
    endinterface
  endinterface

endmodule

`undef TLM_PRM
`undef TLM_RR

endpackage
