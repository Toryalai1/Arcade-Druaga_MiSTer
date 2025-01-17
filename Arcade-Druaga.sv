//============================================================================
//  Arcade: The Tower of Druaga
//
//  Original implementation and MiSTer port by MiSTer-X 2019
//
//  Super Pacman support by Jose Tejada (jotego) March, 2021
//
//============================================================================

module emu
(
		//Master input clock
	input         CLK_50M,

	//Async reset from top-level module.
	//Can be used as initial reset.
	input         RESET,

	//Must be passed to hps_io module
	inout  [48:0] HPS_BUS,

	//Base video clock. Usually equals to CLK_SYS.
	output        CLK_VIDEO,

	//Multiple resolutions are supported using different CE_PIXEL rates.
	//Must be based on CLK_VIDEO
	output        CE_PIXEL,

	//Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
	//if VIDEO_ARX[12] or VIDEO_ARY[12] is set then [11:0] contains scaled size instead of aspect ratio.
	output [12:0] VIDEO_ARX,
	output [12:0] VIDEO_ARY,

	output  [7:0] VGA_R,
	output  [7:0] VGA_G,
	output  [7:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,
	output        VGA_DE,    // = ~(VBlank | HBlank)
	output        VGA_F1,
	output [1:0]  VGA_SL,
	output        VGA_SCALER, // Force VGA scaler
	output        VGA_DISABLE, // analog out is off

	input  [11:0] HDMI_WIDTH,
	input  [11:0] HDMI_HEIGHT,
	output        HDMI_FREEZE,

`ifdef MISTER_FB
	// Use framebuffer in DDRAM
	// FB_FORMAT:
	//    [2:0] : 011=8bpp(palette) 100=16bpp 101=24bpp 110=32bpp
	//    [3]   : 0=16bits 565 1=16bits 1555
	//    [4]   : 0=RGB  1=BGR (for 16/24/32 modes)
	//
	// FB_STRIDE either 0 (rounded to 256 bytes) or multiple of pixel size (in bytes)
	output        FB_EN,
	output  [4:0] FB_FORMAT,
	output [11:0] FB_WIDTH,
	output [11:0] FB_HEIGHT,
	output [31:0] FB_BASE,
	output [13:0] FB_STRIDE,
	input         FB_VBL,
	input         FB_LL,
	output        FB_FORCE_BLANK,

`ifdef MISTER_FB_PALETTE
	// Palette control for 8bit modes.
	// Ignored for other video modes.
	output        FB_PAL_CLK,
	output  [7:0] FB_PAL_ADDR,
	output [23:0] FB_PAL_DOUT,
	input  [23:0] FB_PAL_DIN,
	output        FB_PAL_WR,
`endif
`endif

	output        LED_USER,  // 1 - ON, 0 - OFF.

	// b[1]: 0 - LED status is system status OR'd with b[0]
	//       1 - LED status is controled solely by b[0]
	// hint: supply 2'b00 to let the system control the LED.
	output  [1:0] LED_POWER,
	output  [1:0] LED_DISK,

	// I/O board button press simulation (active high)
	// b[1]: user button
	// b[0]: osd button
	output  [1:0] BUTTONS,

	input         CLK_AUDIO, // 24.576 MHz
	output [15:0] AUDIO_L,
	output [15:0] AUDIO_R,
	output        AUDIO_S,   // 1 - signed audio samples, 0 - unsigned
	output  [1:0] AUDIO_MIX, // 0 - no mix, 1 - 25%, 2 - 50%, 3 - 100% (mono)

//ADC
	inout   [3:0] ADC_BUS,

	//SD-SPI
	output        SD_SCK,
	output        SD_MOSI,
	input         SD_MISO,
	output        SD_CS,
	input         SD_CD,

	//High latency DDR3 RAM interface
	//Use for non-critical time purposes
	output        DDRAM_CLK,
	input         DDRAM_BUSY,
	output  [7:0] DDRAM_BURSTCNT,
	output [28:0] DDRAM_ADDR,
	input  [63:0] DDRAM_DOUT,
	input         DDRAM_DOUT_READY,
	output        DDRAM_RD,
	output [63:0] DDRAM_DIN,
	output  [7:0] DDRAM_BE,
	output        DDRAM_WE,

	//SDRAM interface with lower latency
	output        SDRAM_CLK,
	output        SDRAM_CKE,
	output [12:0] SDRAM_A,
	output  [1:0] SDRAM_BA,
	inout  [15:0] SDRAM_DQ,
	output        SDRAM_DQML,
	output        SDRAM_DQMH,
	output        SDRAM_nCS,
	output        SDRAM_nCAS,
	output        SDRAM_nRAS,
	output        SDRAM_nWE,

	`ifdef MISTER_DUAL_SDRAM
	//Secondary SDRAM
	//Set all output SDRAM_* signals to Z ASAP if SDRAM2_EN is 0
	input         SDRAM2_EN,
	output        SDRAM2_CLK,
	output [12:0] SDRAM2_A,
	output  [1:0] SDRAM2_BA,
	inout  [15:0] SDRAM2_DQ,
	output        SDRAM2_nCS,
	output        SDRAM2_nCAS,
	output        SDRAM2_nRAS,
	output        SDRAM2_nWE,
`endif

	input         UART_CTS,
	output        UART_RTS,
	input         UART_RXD,
	output        UART_TXD,
	output        UART_DTR,
	input         UART_DSR,

	// Open-drain User port.
	// 0 - D+/RX
	// 1 - D-/TX
	// 2..6 - USR2..USR6
	// Set USER_OUT to 1 to read from USER_IN.
	input   [6:0] USER_IN,
	output  [6:0] USER_OUT,

	input         OSD_STATUS
);

assign ADC_BUS  = 'Z;
assign USER_OUT = '1;
assign {UART_RTS, UART_TXD, UART_DTR} = 0;
assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;
assign {SDRAM_DQ, SDRAM_A, SDRAM_BA, SDRAM_CLK, SDRAM_CKE, SDRAM_DQML, SDRAM_DQMH, SDRAM_nWE, SDRAM_nCAS, SDRAM_nRAS, SDRAM_nCS} = 'Z;
assign {DDRAM_CLK, DDRAM_BURSTCNT, DDRAM_ADDR, DDRAM_DIN, DDRAM_BE, DDRAM_RD, DDRAM_WE} = '0;

assign LED_DISK = 0;
assign LED_POWER = 0;
//assign LED_USER = 0;
assign BUTTONS = 0;

assign VGA_F1 = 0;
assign VGA_SCALER = 0;
assign VGA_DISABLE = 0;
assign HDMI_FREEZE = 0;

`include "build_id.v"

localparam CONF_STR = {
	"A.Druaga;;",
	"H0F0,rom;", 	// allow loading of alternate ROMs
	"H0-;",
	"HFO1,Aspect Ratio,Original,Wide;",
	"HFO2,Orientation,Vert,Horz;",
	"O35,Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%,CRT 75%;",
	"O7,Flip Screen,Off,On;",
	"-;",
	"DIP;",
	"-;",
	"R0,Reset;",
	"J1,Trig1,Trig2,Start 1P,Start 2P,Coin;",
	"Jn,A,B,Start,Select,R;",
	"Jp,B,A,Start,Select,R;",
	"V,v",`BUILD_DATE
};

// Status Bitmap:
// 0          1          2          3
// 01234567890123456789012345678901
// 0123456789ABCDEFGHIJKLMNOPQRSTUV
// RAOfffmxttmmmmmmmmmddddooooo FSC

reg   [3:0] tno  = 0;

// DIP switches

wire [23:0] DSWs =
		   (tno==1 || tno==3) ? {sw[1][3:0],sw[2][3:0],sw[1],sw[0]} :
		   (tno==2 ) ? {sw[2][3:0],sw[2][3:0],sw[1],sw[0]} :
		   {sw[2],sw[1],sw[0]};


////////////////////   CLOCKS   ///////////////////

wire clk_48M;
wire clk_hdmi = clk_48M;
wire clk_sys = clk_48M;

pll pll
(
	.rst(0),
	.refclk(CLK_50M),
	.outclk_0(clk_48M)
);

///////////////////////////////////////////////////

wire [31:0] status;
wire  [1:0] buttons;
wire        forced_scandoubler;
wire        direct_video;

wire        ioctl_download;
wire        ioctl_wr;
wire [24:0] ioctl_addr;
wire  [7:0] ioctl_dout;
wire  [7:0] ioctl_index;

wire [10:0] ps2_key;
wire [15:0] joystick_0, joystick_1;

wire [14:0] menumask = ~(15'd1 << tno);
wire [21:0] gamma_bus;

hps_io #(.CONF_STR(CONF_STR)) hps_io
(
  .clk_sys(clk_sys),
  .HPS_BUS(HPS_BUS),
  .EXT_BUS(),
  .gamma_bus(gamma_bus),

  .forced_scandoubler(forced_scandoubler),
  .direct_video(direct_video),
  .status_menumask(direct_video),

  .ioctl_wr(ioctl_wr),
  .ioctl_addr(ioctl_addr),
  .ioctl_dout(ioctl_dout),
  .ioctl_index(ioctl_index),

  .joystick_0(joystick_0),
  .joystick_1(joystick_1),

  .buttons(buttons),
  .status(status),
  .ps2_key(ps2_key),
);

// Retleave Title No.
always @(posedge clk_sys) begin
	if (ioctl_wr & (ioctl_index==1)) tno <= ioctl_dout[3:0];
end

reg [7:0] sw[8];
always @(posedge clk_sys) if (ioctl_wr && (ioctl_index==254) && !ioctl_addr[24:3]) sw[ioctl_addr[2:0]] <= ioctl_dout;


wire       pressed = ps2_key[9];
wire [8:0] code    = ps2_key[8:0];
always @(posedge clk_sys) begin
	reg old_state;
	old_state <= ps2_key[10];

	if(old_state != ps2_key[10]) begin
		casex(code)
			'hX75: btn_up          <= pressed; // up
			'hX72: btn_down        <= pressed; // down
			'hX6B: btn_left        <= pressed; // left
			'hX74: btn_right       <= pressed; // right
			'h029: btn_trig1       <= pressed; // space
			'h014: btn_trig2       <= pressed; // ctrl
			'h005: btn_one_player  <= pressed; // F1
			'h006: btn_two_players <= pressed; // F2

			// JPAC/IPAC/MAME Style Codes
			'h016: btn_start_1     <= pressed; // 1
			'h01E: btn_start_2     <= pressed; // 2
			'h02E: btn_coin_1      <= pressed; // 5
			'h036: btn_coin_2      <= pressed; // 6
			'h02D: btn_up_2        <= pressed; // R
			'h02B: btn_down_2      <= pressed; // F
			'h023: btn_left_2      <= pressed; // D
			'h034: btn_right_2     <= pressed; // G
			'h01C: btn_trig1_2     <= pressed; // A
			'h01B: btn_trig2_2     <= pressed; // S
		endcase
	end
end

reg btn_up    = 0;
reg btn_down  = 0;
reg btn_right = 0;
reg btn_left  = 0;
reg btn_trig1 = 0;
reg btn_trig2 = 0;
reg btn_one_player  = 0;
reg btn_two_players = 0;

reg btn_start_1 = 0;
reg btn_start_2 = 0;
reg btn_coin_1  = 0;
reg btn_coin_2  = 0;
reg btn_up_2    = 0;
reg btn_down_2  = 0;
reg btn_left_2  = 0;
reg btn_right_2 = 0;
reg btn_trig1_2  = 0;
reg btn_trig2_2  = 0;

wire cabinet  = 1'b0;                            // (upright only)

wire m_up2     = btn_up_2    | joystick_1[3];
wire m_down2   = btn_down_2  | joystick_1[2];
wire m_left2   = btn_left_2  | joystick_1[1];
wire m_right2  = btn_right_2 | joystick_1[0];
wire m_trig21  = btn_trig1_2 | joystick_1[4];
wire m_trig22  = btn_trig2_2 | joystick_1[5];

wire m_start1  = btn_one_player  | joystick_0[6] | joystick_1[6] | btn_start_1;
wire m_start2  = btn_two_players | joystick_0[7] | joystick_1[7] | btn_start_2;

wire m_up1     = btn_up      | joystick_0[3] | (cabinet ? 1'b0 : m_up2);
wire m_down1   = btn_down    | joystick_0[2] | (cabinet ? 1'b0 : m_down2);
wire m_left1   = btn_left    | joystick_0[1] | (cabinet ? 1'b0 : m_left2);
wire m_right1  = btn_right   | joystick_0[0] | (cabinet ? 1'b0 : m_right2);
wire m_trig11  = btn_trig1   | joystick_0[4] | (cabinet ? 1'b0 : m_trig21);
wire m_trig12  = btn_trig2   | joystick_0[5] | (cabinet ? 1'b0 : m_trig22);

wire m_coin1   = btn_one_player | btn_coin_1 | joystick_0[8];
wire m_coin2   = btn_two_players| btn_coin_2 | joystick_1[8];


///////////////////////////////////////////////////

// Aspect ratio
wire [1:0] ar = status[3:2];
assign VIDEO_ARX = (!ar) ? 12'd4 : (ar - 1'd1);
assign VIDEO_ARY = (!ar) ? 12'd3 : 12'd0;

// Monochrome video
wire VIDEO, SCORE;
wire HSYNC, VSYNC, HBLANK, VBLANK;
wire [3:0]  video = VIDEO ? 4'hF : SCORE ? 4'hB: 4'h0;
wire [11:0] rgb   = {3{video}};

// ce_pix is on positive edge of video clock (from core)
wire CLK_CORE_VIDEO;
reg  CLK_CORE_VIDEO_q;
wire ce_pix = ~CLK_CORE_VIDEO_q & CLK_CORE_VIDEO;
always_ff @(posedge clk_sys) CLK_CORE_VIDEO_q <= CLK_CORE_VIDEO;

wire [2:0] fx = status[6:4];

arcade_video #(.WIDTH(375), .DW(12)) arcade_video
(
  .*,

  .clk_video(clk_sys),
  .ce_pix(ce_pix),

  .RGB_in(rgb),
  .HBlank(HBLANK),
  .VBlank(VBLANK),
  .HSync(HSYNC),
  .VSync(VSYNC),

  .fx,
  .forced_scandoubler,
  .gamma_bus
);

wire			PCLK;
wire  [8:0] HPOS,VPOS;
wire [11:0] POUT;
HVGEN hvgen
(
	.HPOS(HPOS),.VPOS(VPOS),.PCLK(PCLK),.iRGB(POUT),
	.oRGB({b,g,r}),.HBLK(hblank),.VBLK(vblank),.HSYN(hs),.VSYN(vs)
);
assign ce_vid = PCLK;


wire [15:0] SOUND;
assign AUDIO_L = SOUND;
assign AUDIO_R = AUDIO_L;
assign AUDIO_S = 1;
assign AUDIO_MIX = 3;


///////////////////////////////////////////////////

wire	iRST = RESET | status[0] | buttons[1] | ioctl_download;

wire  [5:0]	INP0 = { m_trig12, m_trig11, m_left1, m_down1, m_right1, m_up1 };
wire  [5:0]	INP1 = { m_trig22, m_trig21, m_left2, m_down2, m_right2, m_up2 };
wire	[2:0]	INP2 = { (m_coin1|m_coin2), m_start2, m_start1 };

wire  [7:0] oPIX;
wire  [7:0] oSND;

fpga_druaga GameCore (
	.RESET(iRST),.MCLK(clk_48M),
	.PH(HPOS),.PV(VPOS),.PCLK(PCLK),.POUT(oPIX),
	.SOUT(oSND),

	.INP0(INP0),.INP1(INP1),.INP2(INP2),
	.DSW0(DSWs[7:0]),.DSW1(DSWs[15:8]),.DSW2(DSWs[23:16]),

	.ROMCL(clk_sys),.ROMAD(ioctl_addr),.ROMDT(ioctl_dout),.ROMEN(ioctl_wr & (ioctl_index == 0)),
	.MODEL( tno[2:0] ),	// Selects the system
	.flip_screen(status[7])
);

assign POUT = {oPIX[7:6],2'b00,oPIX[5:3],1'b0,oPIX[2:0],1'b0};
assign AOUT = {oSND,8'h0};

endmodule


module HVGEN
(
	output  [8:0]		HPOS,
	output  [8:0]		VPOS,
	input 				PCLK,
	input	 [11:0]		iRGB,

	output reg [11:0]	oRGB,
	output reg			HBLK = 1,
	output reg			VBLK = 1,
	output reg			HSYN = 1,
	output reg			VSYN = 1
);

reg [8:0] hcnt = 0;
reg [8:0] vcnt = 0;

assign HPOS = hcnt;
assign VPOS = vcnt;

always @(posedge PCLK) begin
	case (hcnt)
		  1: begin HBLK <= 0; hcnt <= hcnt+1; end
		290: begin HBLK <= 1; hcnt <= hcnt+1; end
		311: begin HSYN <= 0; hcnt <= hcnt+1; end
		342: begin HSYN <= 1; hcnt <= 471;    end
		511: begin hcnt <= 0;
			case (vcnt)
				223: begin VBLK <= 1; vcnt <= vcnt+1; end
				234: begin VSYN <= 0; vcnt <= vcnt+1; end
				241: begin VSYN <= 1; vcnt <= 491;    end
				511: begin VBLK <= 0; vcnt <= 0;	     end
				default: vcnt <= vcnt+1;
			endcase
		end
		default: hcnt <= hcnt+1;
	endcase
	oRGB <= (HBLK|VBLK) ? 12'h0 : iRGB;
end

endmodule

