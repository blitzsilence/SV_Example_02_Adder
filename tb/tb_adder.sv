// DUT Interface
interface adder_if();
  logic        rstn;
  logic [7:0]  a;
  logic [7:0]  b;
  logic [7:0]  sum;
  logic        carry;
endinterface

// Clock Interface
interface clk_if();
  logic tb_clk;
	
  initial begin
		tb_clk = 0;
		
		forever 
			#10 tb_clk = ~tb_clk;
	end
endinterface


// Transaction
class packet;

  rand bit	rstn; 
  rand bit[7:0]	a;
  rand bit[7:0] b; 
  bit [7:0]	sum;  
  bit carry;    

  function void print(string tag="");
    $display("T: %0t, [%s] a=0x%0h, b=0x%0h, sum=0x%0h, carry=0x%0h", $time, tag, a, b, sum, carry);
  endfunction

  function packet copy();
		packet pkt = new;
		
    pkt.a 		= this.a;
    pkt.b 		= this.b;
    pkt.rstn 	= this.rstn;
    pkt.sum 	= this.sum;
    pkt.carry = this.carry;
		
		return pkt;
  endfunction
	
endclass


// Generator
class generator;
  mailbox #(packet) drv_mbx;
	
	event drv_done;
	int  loop = 10;

  task run();
    for (int i = 0; i < loop; i++) begin
      packet item = new;
			
      assert(item.randomize())
			else
				$fatal("Randomize failed");
				
      $display("T: %0t, [Generator] Loop:%0d/%0d create next item", $time, i+1, loop);
			
      drv_mbx.put(item);
      $display("T: %0t, [Generator] Wait for driver to be done", $time);
			
			// wiat for the response from driver
      @(drv_done);
    end
  endtask
endclass


// Driver
class driver;

  virtual adder_if m_adder_vif;
  virtual clk_if  m_clk_vif;
	
  mailbox #(packet) drv_mbx;
	
	event drv_done;

  task run();
    forever begin
      packet item;
      drv_mbx.get(item);
			
      @(negedge m_clk_vif.tb_clk);  // negedge clk, avoid racing with monitor
      item.print("Driver");
			
      m_adder_vif.rstn <= item.rstn;
      m_adder_vif.a    <= item.a;
      m_adder_vif.b    <= item.b;
			
			// inform generator
      ->drv_done; 
    end
  endtask
endclass


// Monitor
class monitor;
  virtual adder_if m_adder_vif;
  virtual clk_if   m_clk_vif;
	
  mailbox #(packet) scb_mbx;

  task run();
    forever begin
      packet m_pkt = new;
			
      @(posedge m_clk_vif.tb_clk);
      #1step;				// avoid sampling race condition
			
      m_pkt.a     = m_adder_vif.a;
      m_pkt.b     = m_adder_vif.b;
      m_pkt.rstn  = m_adder_vif.rstn;
      m_pkt.sum   = m_adder_vif.sum;
      m_pkt.carry = m_adder_vif.carry;
      m_pkt.print("Monitor");
			
      scb_mbx.put(m_pkt); 
    end
  endtask
endclass


// Scoreboard
class scoreboard;
  mailbox #(packet) scb_mbx;

  task run();
	
    forever begin
		
      packet item, ref_item;
			
      scb_mbx.get(item);
      item.print("Scoreboard");

      ref_item = item.copy();		// deep coopy

      // Comparison - reset period
      if (!ref_item.rstn)
				{ref_item.carry, ref_item.sum} = 0;
			else
        {ref_item.carry, ref_item.sum} = ref_item.a + ref_item.b;

      // Comparison - carry
      if (ref_item.carry != item.carry)
        $display("T: %0t, [Scoreboard] Error! Carry mismatch ref_item=0x%0h, item=0x%0h", $time, ref_item.carry, item.carry);
      else
        $display("T: %0t, [Scoreboard] Pass! Carry match", $time);

			// Comparison - sum
      if (ref_item.sum != item.sum)
        $display("T: %0t, [Scoreboard] Error! Sum mismatch ref_item=0x%0h, item=0x%0h", $time, ref_item.sum, item.sum);
      else
        $display("T: %0t, [Scoreboard] Pass! Sum match", $time);
    end
  endtask
endclass


// Environment
class environment;
  generator     gen;
  driver        drv;
  monitor       mon;
  scoreboard    scb;
	
  mailbox #(packet)	scb_mbx;
  mailbox #(packet)	drv_mbx;
	
  virtual adder_if m_adder_vif;
  virtual clk_if   m_clk_vif;
	
	event	drv_done;
	
	// component instantiation
  function new();
    gen = new; 
		drv = new; 
		mon = new; 
		scb = new;
		
    scb_mbx = new; 
		drv_mbx = new;
  endfunction

  virtual task run();
    // interface connection 
    drv.m_adder_vif = m_adder_vif;
    mon.m_adder_vif = m_adder_vif;
    drv.m_clk_vif = m_clk_vif;
    mon.m_clk_vif = m_clk_vif;

    // mailbox connection 
    drv.drv_mbx = drv_mbx;
    gen.drv_mbx = drv_mbx;
    mon.scb_mbx = scb_mbx;
    scb.scb_mbx = scb_mbx;

    // event connection
    drv.drv_done = drv_done;
    gen.drv_done = drv_done;

    // start run
    fork : RUN_FORK
			gen.run();
      scb.run();
      drv.run();
      mon.run();
    join_any
		
		#5000ns;
		disable RUN_FORK;		
		
  endtask
endclass


// Test 
class test;
  environment env;

  function new();
    env = new();
  endfunction

  virtual task run();
    env.run();
  endtask
endclass


// Top_tb
module tb_adder;
  clk_if    m_clk_if(); 
  adder_if  m_adder_if();
	
  my_adder  dut(m_adder_if);

  initial begin
    test t0;
    t0 = new;
		
    t0.env.m_adder_vif = m_adder_if;
    t0.env.m_clk_vif   = m_clk_if;
		
    t0.run(); 
		
		$finish;
  end
	
	
	// DUMP FSDB
  initial begin
    $fsdbDumpfile("tb_adder.fsdb");
    $fsdbDumpvars(0, "tb_adder");
  end	
	
endmodule