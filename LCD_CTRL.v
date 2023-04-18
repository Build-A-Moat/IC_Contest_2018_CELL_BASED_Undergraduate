module LCD_CTRL (
    clk,
    reset,
    cmd,
    cmd_valid,
    IROM_Q,
    IROM_rd,
    IROM_A,
    IRAM_valid,
    IRAM_D,
    IRAM_A,
    busy,
    done
);
  input clk;
  input reset;
  input [3:0] cmd;
  input cmd_valid;
  input [7:0] IROM_Q;
  output reg IROM_rd;
  output reg [5:0] IROM_A;
  output reg IRAM_valid;
  output reg [7:0] IRAM_D;
  output reg [5:0] IRAM_A;
  output reg busy;
  output reg done;
  parameter high = 1'b1;
  parameter low = 1'b0;
  reg [5:0] address, L1_address, L2_address, R1_address, R2_address;
  reg READ;
  reg last_write;
  reg pull_done;
  reg [2:0] point_x;
  reg [2:0] point_y;
  reg [7:0] max, min;
  wire [5:0] point;
  reg write;
  reg [9:0] sum;
  reg [7:0] image[63:0];
  assign point = {point_x, point_y};
  always @(posedge clk) begin
    if (reset) begin
      busy <= high;
      address <= 6'b0;
      READ <= high;
      last_write <= low;
      pull_done <= low;
      point_x <= 3'b100;
      point_y <= 3'b100;
      write <= low;
    end else if (cmd_valid == high && busy == low) busy <= high;
  end


  always @(posedge clk) begin
    if (busy == high)
      case (cmd)
        4'b0000: begin  // Write
          write <= high;
        end


        4'b0001: begin  // Shift Up
          if (point_y != 3'b1) point_y <= point_y - 1'b1;
          busy <= low;
        end
        4'b0010: begin  // Shift Down
          if (point_y != 3'b111) point_y <= point_y + 1'b1;
          busy <= low;
        end
        4'b0011: begin  // Shift Left
          if (point_x != 3'b1) point_x <= point_x - 1'b1;
          busy <= low;
        end
        4'b0100: begin  // Shift Right
          if (point_x != 3'b111) point_x <= point_x + 1'b1;
          busy <= low;
        end


        4'b0101: begin  // Max
          image[L1_address] <= max;
          image[L2_address] <= max;
          image[R1_address] <= max;
          image[R2_address] <= max;
          busy <= low;
        end
        4'b0110: begin  // Min
          image[L1_address] <= min;
          image[L2_address] <= min;
          image[R1_address] <= min;
          image[R2_address] <= min;
          busy <= low;
        end
        4'b0111: begin  // Average
          image[L1_address] <= sum[9:2];
          image[L2_address] <= sum[9:2];
          image[R1_address] <= sum[9:2];
          image[R2_address] <= sum[9:2];
          busy <= low;
        end
        4'b1000: begin  // Counterclockwise Rotation
          image[L1_address] <= image[R1_address];
          image[L2_address] <= image[L1_address];
          image[R1_address] <= image[R2_address];
          image[R2_address] <= image[L2_address];
          busy <= low;
        end
        4'b1001: begin  // Clockwise Rotation
          image[L1_address] <= image[L2_address];
          image[L2_address] <= image[R2_address];
          image[R1_address] <= image[L1_address];
          image[R2_address] <= image[R1_address];
          busy <= low;
        end
        4'b1010: begin  // Mirror X
          image[L1_address] <= image[L2_address];
          image[L2_address] <= image[L1_address];
          image[R1_address] <= image[R2_address];
          image[R2_address] <= image[R1_address];
          busy <= low;
        end
        4'b1011: begin  // Mirror Y
          image[L1_address] <= image[R1_address];
          image[L2_address] <= image[R2_address];
          image[R1_address] <= image[L1_address];
          image[R2_address] <= image[L2_address];
          busy <= low;
        end
      endcase
  end

  always @(posedge clk) begin
    if(READ == high) begin
      if (address == 6'h0) begin
        IROM_rd <= high;
        IROM_A <= address;
        address <= address + 1'b1;
      end else if (last_write == high) begin
        last_write <= low;
        image[address] <= IROM_Q;
        pull_done <= high;
      end else if (pull_done == high) begin
        address <= 6'b0;
        IROM_rd <= low;
        busy <= low;
        pull_done <= low;
        READ <= low;
      end else if (address == 6'h3f) begin
        IROM_A <= address;
        image[address - 1'b1] <= IROM_Q;
        last_write <= high;        
      end else begin
        IROM_A  <= address;
        image[address - 1'b1] <= IROM_Q;
        address <= address + 1'b1;
      end 
    end
  end

  always @(posedge clk) begin
    if(write == high) begin
      if (address == 6'h0) begin
        IRAM_valid <= high;
        IRAM_A <= address;
        IRAM_D <= image[address];
        address <= address + 1'b1;
      end else if (last_write == high) begin
        last_write <= low;
        pull_done <= high;
      end else if (pull_done == high) begin
        address <= 6'b0;
        IRAM_valid <= low;
        busy <= low;
        done <= high;
        pull_done <= low;
        write <= low;
      end else if (address == 6'h3f) begin
        IRAM_A <= address;
        IRAM_D <= image[address];
        last_write <= high;        
      end else begin
        IRAM_A <= address;
        IRAM_D <= image[address];
        address <= address + 1'b1;
      end 
    end
  end

// max
  always @(*) begin
    if (image[L1_address] > image[L2_address] && image[L1_address] > image[R1_address] && image[L1_address] > image[R2_address]) max <= image[L1_address];
    else if (image[L2_address] > image[L1_address] && image[L2_address] > image[R1_address] && image[L2_address] > image[R2_address]) max <= image[L2_address];
    else if (image[R1_address] > image[L1_address] && image[R1_address] > image[L2_address] && image[R1_address] > image[R2_address]) max <= image[R1_address];
    else max <= image[R2_address];
  end

  // min
  always @(*) begin
    if (image[L1_address] < image[L2_address] && image[L1_address] < image[R1_address] && image[L1_address] < image[R2_address]) min <= image[L1_address];
    else if (image[L2_address] < image[L1_address] && image[L2_address] < image[R1_address] && image[L2_address] < image[R2_address]) min <= image[L2_address];
    else if (image[R1_address] < image[L1_address] && image[R1_address] < image[L2_address] && image[R1_address] < image[R2_address]) min <= image[R1_address];
    else min <= image[R2_address];
  end

  always @(*) begin
    sum <= image[L1_address] + image[L2_address] + image[R1_address] + image[R2_address];
  end

  always @(point) begin
    case (point)
  6'b001001 : begin
    L1_address = 6'h0;
    L2_address = 6'h8;
    R1_address = 6'h1;
    R2_address = 6'h9;
  end
  6'b010001 : begin
    L1_address = 6'h1;
    L2_address = 6'h9;
    R1_address = 6'h2;
    R2_address = 6'ha;
  end
  6'b011001 : begin
    L1_address = 6'h2;
    L2_address = 6'ha;
    R1_address = 6'h3;
    R2_address = 6'hb;
  end
  6'b100001 : begin
    L1_address = 6'h3;
    L2_address = 6'hb;
    R1_address = 6'h4;
    R2_address = 6'hc;
  end
  6'b101001 : begin
    L1_address = 6'h4;
    L2_address = 6'hc;
    R1_address = 6'h5;
    R2_address = 6'hd;
  end
  6'b110001 : begin
    L1_address = 6'h5;
    L2_address = 6'hd;
    R1_address = 6'h6;
    R2_address = 6'he;
  end
  6'b111001 : begin
    L1_address = 6'h6;
    L2_address = 6'he;
    R1_address = 6'h7;
    R2_address = 6'hf;
  end
  6'b001010 : begin
    L1_address = 6'h8;
    L2_address = 6'h10;
    R1_address = 6'h9;
    R2_address = 6'h11;
  end
  6'b010010 : begin
    L1_address = 6'h9;
    L2_address = 6'h11;
    R1_address = 6'hA;
    R2_address = 6'h12;
  end
  6'b011010 : begin
    L1_address = 6'hA;
    L2_address = 6'h12;
    R1_address = 6'hB;
    R2_address = 6'h13;
  end
  6'b100010 : begin
    L1_address = 6'hB;
    L2_address = 6'h13;
    R1_address = 6'hC;
    R2_address = 6'h14;
  end
  6'b101010 : begin
    L1_address = 6'hC;
    L2_address = 6'h14;
    R1_address = 6'hD;
    R2_address = 6'h15;
  end
  6'b110010 : begin
    L1_address = 6'hD;
    L2_address = 6'h15;
    R1_address = 6'hE;
    R2_address = 6'h16;
  end
  6'b111010 : begin
    L1_address = 6'hE;
    L2_address = 6'h16;
    R1_address = 6'hF;
    R2_address = 6'h17;
  end
  6'b001011 : begin
    L1_address = 6'h10;
    L2_address = 6'h18;
    R1_address = 6'h11;
    R2_address = 6'h19;
    end
  6'b010011 : begin
    L1_address = 6'h11;
    L2_address = 6'h19;
    R1_address = 6'h12;
    R2_address = 6'h1A;
  end
  6'b011011 : begin
    L1_address = 6'h12;
    L2_address = 6'h1A;
    R1_address = 6'h13;
    R2_address = 6'h1B;
  end
  6'b100011 : begin
    L1_address = 6'h13;
    L2_address = 6'h1b;
    R1_address = 6'h14;
    R2_address = 6'h1C;
  end
  6'b101011 : begin
    L1_address = 6'h14;
    L2_address = 6'h1C;
    R1_address = 6'h15;
    R2_address = 6'h1D;
  end
  6'b110011 : begin
    L1_address = 6'h15;
    L2_address = 6'h1D;
    R1_address = 6'h16;
    R2_address = 6'h1E;
  end
  6'b111011 : begin
    L1_address = 6'h16;
    L2_address = 6'h1E;
    R1_address = 6'h17;
    R2_address = 6'h1F;
  end
  6'b001100 : begin
    L1_address = 6'h18;
    L2_address = 6'h20;
    R1_address = 6'h19;
    R2_address = 6'h21;
  end
  6'b010100 : begin
    L1_address = 6'h19;
    L2_address = 6'h21;
    R1_address = 6'h1A;
    R2_address = 6'h22;
  end
  6'b011100 : begin
    L1_address = 6'h1A;
    L2_address = 6'h22;
    R1_address = 6'h1B;
    R2_address = 6'h23;
  end
  6'b100100 : begin
    L1_address = 6'h1B;
    L2_address = 6'h23;
    R1_address = 6'h1C;
    R2_address = 6'h24;
  end
  6'b101100 : begin
    L1_address = 6'h1C;
    L2_address = 6'h24;
    R1_address = 6'h1D;
    R2_address = 6'h25;
  end
  6'b110100 : begin
    L1_address = 6'h1D;
    L2_address = 6'h25;
    R1_address = 6'h1E;
    R2_address = 6'h26;
  end
  6'b111100 : begin
    L1_address = 6'h1E;
    L2_address = 6'h26;
    R1_address = 6'h1F;
    R2_address = 6'h27;
  end
  ///
  6'b001101 : begin
    L1_address = 6'h20;
    L2_address = 6'h28;
    R1_address = 6'h21;
    R2_address = 6'h29;
  end
  6'b010101 : begin
    L1_address = 6'h21;
    L2_address = 6'h29;
    R1_address = 6'h22;
    R2_address = 6'h2A;
  end
  6'b011101 : begin
    L1_address = 6'h22;
    L2_address = 6'h2A;
    R1_address = 6'h23;
    R2_address = 6'h2B;
  end
  6'b100101 : begin
    L1_address = 6'h23;
    L2_address = 6'h2B;
    R1_address = 6'h24;
    R2_address = 6'h2C;
  end
  6'b101101 : begin
    L1_address = 6'h24;
    L2_address = 6'h2C;
    R1_address = 6'h25;
    R2_address = 6'h2D;
  end
  6'b110101 : begin
    L1_address = 6'h25;
    L2_address = 6'h2D;
    R1_address = 6'h26;
    R2_address = 6'h2E;
  end
  6'b111101 : begin
    L1_address = 6'h26;
    L2_address = 6'h2E;
    R1_address = 6'h27;
    R2_address = 6'h2F;
  end
  6'b001110 : begin
    L1_address = 6'h28;
    L2_address = 6'h30;
    R1_address = 6'h29;
    R2_address = 6'h31;
  end
  6'b010110 : begin
    L1_address = 6'h29;
    L2_address = 6'h31;
    R1_address = 6'h2A;
    R2_address = 6'h32;
  end
  6'b011110 : begin
    L1_address = 6'h2A;
    L2_address = 6'h32;
    R1_address = 6'h2B;
    R2_address = 6'h33;
  end
  6'b100110 : begin
    L1_address = 6'h2B;
    L2_address = 6'h33;
    R1_address = 6'h2C;
    R2_address = 6'h34;
  end
  6'b101110 : begin
    L1_address = 6'h2C;
    L2_address = 6'h34;
    R1_address = 6'h2D;
    R2_address = 6'h35;
  end
  6'b110110 : begin
    L1_address = 6'h2D;
    L2_address = 6'h35;
    R1_address = 6'h2E;
    R2_address = 6'h36;
  end
  6'b111110 : begin
    L1_address = 6'h2e;
    L2_address = 6'h36;
    R1_address = 6'h2f;
    R2_address = 6'h37;
  end
  6'b001111 : begin
    L1_address = 6'h30;
    L2_address = 6'h38;
    R1_address = 6'h31;
    R2_address = 6'h39;
  end
  6'b010111 : begin
    L1_address = 6'h31;
    L2_address = 6'h39;
    R1_address = 6'h32;
    R2_address = 6'h3a;
  end
  6'b011111 : begin
    L1_address = 6'h32;
    L2_address = 6'h3a;
    R1_address = 6'h33;
    R2_address = 6'h3b;
  end
  6'b100111 : begin
    L1_address = 6'h33;
    L2_address = 6'h3b;
    R1_address = 6'h34;
    R2_address = 6'h3c;
  end
  6'b101111 : begin
    L1_address = 6'h34;
    L2_address = 6'h3c;
    R1_address = 6'h35;
    R2_address = 6'h3d;
  end
  6'b110111 : begin
    L1_address = 6'h35;
    L2_address = 6'h3d;
    R1_address = 6'h36;
    R2_address = 6'h3e;
  end
  6'b111111 : begin
    L1_address = 6'h36;
    L2_address = 6'h3e;
    R1_address = 6'h37;
    R2_address = 6'h3f;
  end
  endcase
  end
endmodule
