module my_adder (adder_if my_if);

  always_comb begin
	
    if (!my_if.rstn) begin
      my_if.sum 	= 0;
      my_if.carry = 0;
    end 
		else begin
      {my_if.carry, my_if.sum} = my_if.a + my_if.b;
    end
		
  end
endmodule