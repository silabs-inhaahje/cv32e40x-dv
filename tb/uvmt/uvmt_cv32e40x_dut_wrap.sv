//
// Copyright 2020 OpenHW Group
// Copyright 2020 Datum Technology Corporation
// Copyright 2020 Silicon Labs, Inc.
//
// Licensed under the Solderpad Hardware Licence, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     https://solderpad.org/licenses/
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
///////////////////////////////////////////////////////////////////////////////
//
// Modified version of the wrapper for a RI5CY testbench, containing RI5CY,
// plus Memory and stdout virtual peripherals.
// Contributor: Robert Balas <balasr@student.ethz.ch>
// Copyright 2018 Robert Balas <balasr@student.ethz.ch>
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.
//


`ifndef __UVMT_CV32E40X_DUT_WRAP_SV__
`define __UVMT_CV32E40X_DUT_WRAP_SV__


/**
 * Module wrapper for CV32E40X RTL DUT.
 */
module uvmt_cv32e40x_dut_wrap
  import cv32e40x_pkg::*;
#(
    // DUT (riscv_core) parameters.
    parameter NUM_MHPMCOUNTERS    =  1,
    parameter logic [31:0]           DM_REGION_START                     = 32'hF0000000,
    parameter logic [31:0]           DM_REGION_END                       = 32'hF0003FFF,
    parameter m_ext_e                M_EXT                               = M,
    parameter cv32e40x_pkg::a_ext_e  A_EXT                               = cv32e40x_pkg::A_NONE,
    parameter cv32e40x_pkg::b_ext_e  B_EXT                               = cv32e40x_pkg::B_NONE,
    parameter int                    PMA_NUM_REGIONS                     = 0,
    parameter pma_cfg_t              PMA_CFG[PMA_NUM_REGIONS-1 : 0]      = '{default:PMA_R_DEFAULT},
    parameter logic                  CLIC                                = 0,
    parameter int                    CLIC_ID_WIDTH                       = 5,
    parameter int                    CLIC_INTTHRESHBITS                  = 8,
    parameter int                    DBG_NUM_TRIGGERS                    = 1,
    parameter rv32_e                 RV32                                = RV32I,

    // Remaining parameters are used by TB components only
    parameter INSTR_ADDR_WIDTH    =  32,
    parameter INSTR_RDATA_WIDTH   =  32,
    parameter RAM_ADDR_WIDTH      =  20
  )
  (
    uvma_clknrst_if_t               clknrst_if,
    uvma_interrupt_if_t             interrupt_if,
    uvma_clic_if_t                  clic_if,
    uvmt_cv32e40x_vp_status_if_t    vp_status_if,
    uvme_cv32e40x_core_cntrl_if_t   core_cntrl_if,
    uvmt_cv32e40x_core_status_if_t  core_status_if,
    uvma_obi_memory_if_t            obi_instr_if,
    uvma_obi_memory_if_t            obi_data_if,
    uvma_fencei_if_t                fencei_if
  );

    import uvm_pkg::*; // needed for the UVM messaging service (`uvm_info(), etc.)
    /*
    // signals connecting core to memory
    logic                         instr_req;
    logic                         instr_gnt;
    logic                         instr_rvalid;
    logic [INSTR_ADDR_WIDTH-1 :0] instr_addr;
    logic [INSTR_RDATA_WIDTH-1:0] instr_rdata;

    logic                         data_req;
    logic                         data_gnt;
    logic                         data_rvalid;
    logic [31:0]                  data_addr;
    logic                         data_we;
    logic [3:0]                   data_be;
    logic [31:0]                  data_rdata;
    logic [31:0]                  data_wdata;

    logic [31:0]                  irq;
  */
    logic                         debug_havereset;
    logic                         debug_running;
    logic                         debug_halted;
    logic                         debug_pc_valid;
    logic [31:0]                  debug_pc;

    // eXtension interface
    // todo: Connect to TB when implemented.
    // Included to allow core-v-verif to compile with RTL including
    // interface definition.
    cv32e40x_if_xif xif();

    assign debug_if.clk      = clknrst_if.clk;
    assign debug_if.reset_n  = clknrst_if.reset_n;

    // --------------------------------------------
    // OBI Instruction agent v1.2 signal tie-offs
    assign obi_instr_if.we        = 'b0;
    assign obi_instr_if.be        = 'hf; // Always assumes 32-bit full bus reads on instruction OBI
    assign obi_instr_if.auser     = 'b0;
    assign obi_instr_if.wuser     = 'b0;
    assign obi_instr_if.aid       = 'b0;
    assign obi_instr_if.wdata     = 'b0;
    assign obi_instr_if.reqpar    = ~obi_instr_if.req;
    assign obi_instr_if.rready    = 1'b1;
    assign obi_instr_if.rreadypar = 1'b0;

    // --------------------------------------------
    // OBI Data agent v1.2 signal tie-offs
    assign obi_data_if.auser      = 'b0;
    assign obi_data_if.wuser      = 'b0;
    assign obi_data_if.aid        = 'b0;
    assign obi_data_if.reqpar     = ~obi_data_if.req;
    assign obi_data_if.rready     = 1'b1;
    assign obi_data_if.rreadypar  = 1'b0;

    // --------------------------------------------
    // Connect to uvma_interrupt_if
    assign interrupt_if.clk         = clknrst_if.clk;
    assign interrupt_if.reset_n     = clknrst_if.reset_n;
    assign interrupt_if.irq_id      = cv32e40x_wrapper_i.core_i.irq_id;
    assign interrupt_if.irq_ack     = cv32e40x_wrapper_i.core_i.irq_ack;

    // --------------------------------------------
    assign clic_if.clk              = clknrst_if.clk;
    assign clic_if.reset_n          = clknrst_if.reset_n;
    assign clic_if.irq_ack          = cv32e40x_wrapper_i.core_i.irq_ack;

    // --------------------------------------------
    // Connect to core_cntrl_if
    assign core_cntrl_if.num_mhpmcounters = NUM_MHPMCOUNTERS;
    assign core_cntrl_if.b_ext = B_EXT;
    `ifndef FORMAL
    initial begin
      core_cntrl_if.pma_cfg = new[PMA_NUM_REGIONS];
      foreach (core_cntrl_if.pma_cfg[i]) begin
        core_cntrl_if.pma_cfg[i].word_addr_low  = PMA_CFG[i].word_addr_low;
        core_cntrl_if.pma_cfg[i].word_addr_high = PMA_CFG[i].word_addr_high;
        core_cntrl_if.pma_cfg[i].main           = PMA_CFG[i].main;
        core_cntrl_if.pma_cfg[i].bufferable     = PMA_CFG[i].bufferable;
        core_cntrl_if.pma_cfg[i].cacheable      = PMA_CFG[i].cacheable;
        core_cntrl_if.pma_cfg[i].atomic         = PMA_CFG[i].atomic;
      end
    end
    `endif

    // --------------------------------------------
    // instantiate the core
    cv32e40x_wrapper #(
                      .NUM_MHPMCOUNTERS (NUM_MHPMCOUNTERS),
                      .A_EXT                (A_EXT),
                      .B_EXT                (B_EXT),
                      .DBG_NUM_TRIGGERS     (DBG_NUM_TRIGGERS),
                      .DM_REGION_END        (DM_REGION_END),
                      .DM_REGION_START      (DM_REGION_START),
                      .M_EXT                (M_EXT),
                      .PMA_CFG              (PMA_CFG),
                      .PMA_NUM_REGIONS      (PMA_NUM_REGIONS),
                      .RV32                 (RV32),
                      .CLIC                 (CLIC),
                      .CLIC_ID_WIDTH        (CLIC_ID_WIDTH)
                      )
    cv32e40x_wrapper_i
        (
         .clk_i                  ( clknrst_if.clk                 ),
         .rst_ni                 ( clknrst_if.reset_n             ),

         .scan_cg_en_i           ( core_cntrl_if.scan_cg_en       ),

         .boot_addr_i            ( core_cntrl_if.boot_addr        ),
         .mtvec_addr_i           ( core_cntrl_if.mtvec_addr       ),
         .dm_halt_addr_i         ( core_cntrl_if.dm_halt_addr     ),
         .mhartid_i              ( core_cntrl_if.mhartid          ),
         .mimpid_patch_i         ( core_cntrl_if.mimpid_patch     ),
         .dm_exception_addr_i    ( core_cntrl_if.dm_exception_addr),

         .instr_req_o            ( obi_instr_if.req               ),
         .instr_gnt_i            ( obi_instr_if.gnt               ),
         .instr_addr_o           ( obi_instr_if.addr              ),
         .instr_prot_o           ( obi_instr_if.prot              ),
         .instr_dbg_o            ( obi_instr_if.dbg               ),
         .instr_memtype_o        ( obi_instr_if.memtype           ),
         .instr_rdata_i          ( obi_instr_if.rdata             ),
         .instr_rvalid_i         ( obi_instr_if.rvalid            ),
         .instr_err_i            ( obi_instr_if.err               ),

         .data_req_o             ( obi_data_if.req                ),
         .data_gnt_i             ( obi_data_if.gnt                ),
         .data_rvalid_i          ( obi_data_if.rvalid             ),
         .data_we_o              ( obi_data_if.we                 ),
         .data_be_o              ( obi_data_if.be                 ),
         .data_addr_o            ( obi_data_if.addr               ),
         .data_wdata_o           ( obi_data_if.wdata              ),
         .data_prot_o            ( obi_data_if.prot               ),
         .data_dbg_o             ( obi_data_if.dbg                ),
         .data_memtype_o         ( obi_data_if.memtype            ),
         .data_rdata_i           ( obi_data_if.rdata              ),
         .data_atop_o            ( obi_data_if.atop               ),
         .data_err_i             ( obi_data_if.err                ),
         .data_exokay_i          ( obi_data_if.exokay             ),
         .xif_compressed_if      ( xif.cpu_compressed             ),
         .xif_issue_if           ( xif.cpu_issue                  ),
         .xif_commit_if          ( xif.cpu_commit                 ),
         .xif_mem_if             ( xif.cpu_mem                    ),
         .xif_mem_result_if      ( xif.cpu_mem_result             ),
         .xif_result_if          ( xif.cpu_result                 ),

         .mcycle_o               ( /*todo: connect */             ),

         .irq_i                  ( interrupt_if.irq               ),
         .wu_wfe_i               ( 1'b0                           ), // todo: hook up
         .clic_irq_i             ( clic_if.clic_irq               ),
         .clic_irq_id_i          ( clic_if.clic_irq_id            ),
         .clic_irq_level_i       ( clic_if.clic_irq_level         ),
         .clic_irq_priv_i        ( clic_if.clic_irq_priv          ),
         .clic_irq_shv_i         ( clic_if.clic_irq_shv           ),


         .fencei_flush_req_o     ( fencei_if.flush_req          ),
         .fencei_flush_ack_i     ( fencei_if.flush_ack          ),

         .debug_req_i            ( debug_if.debug_req             ),
         .debug_havereset_o      ( debug_havereset                ),
         .debug_running_o        ( debug_running                  ),
         .debug_halted_o         ( debug_halted                   ),
         .debug_pc_valid_o       ( debug_pc_valid                 ),
         .debug_pc_o             ( debug_pc                       ),

         .fetch_enable_i         ( core_cntrl_if.fetch_en         ),
         .core_sleep_o           ( core_status_if.core_busy       )
        );

endmodule : uvmt_cv32e40x_dut_wrap

`endif // __UVMT_CV32E40X_DUT_WRAP_SV__
