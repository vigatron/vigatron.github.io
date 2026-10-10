----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    15:26:30 04/14/2011 
-- Design Name: 
-- Module Name:    gvif - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.numeric_std.all;
use IEEE.STD_LOGIC_ARITH.ALL;


-- SIG_HSYNC	: out std_logic; 	-- Hor.Sync / Line promotion
-- SIG_VSYNC	: out std_logic; 	-- Ver.Sync / Frame Promotion

--
entity gvif is
    Port ( 	CLK33 	: in STD_LOGIC;	-- Base GVIF Frequency
				RESET 	: in STD_LOGIC;
			  
				-- ----------------------------------------- --
				-- Hardware mapping 									--
				-- ----------------------------------------- --
				PIN_GVIF_CLK 	: out std_logic;
				PIN_GVIF_HS		: out std_logic;
				PIN_GVIF_VS		: out std_logic;
				PIN_GVIF_DE		: out std_logic;
				PIN_GVIF_CTL	: out std_logic;
				PIN_GVIF_R		: out std_logic_vector(7 downto 0);
				PIN_GVIF_G		: out std_logic_vector(7 downto 0);
				PIN_GVIF_B		: out std_logic_vector(7 downto 0);

			   -- -------------------------------------- --
				-- Setup Bus 										--
				-- -------------------------------------- --
				SETUP_CLK	: in std_logic;
				SETUP_CLR 	: in STD_LOGIC;
				SETUP_BUS 	: in STD_LOGIC_VECTOR(7 downto 0);
				SETUP_WR  	: in STD_LOGIC;

				-- ----------------------------------------- --
				-- Color Info @ 133 Mhz						 		--
				-- ----------------------------------------- --
				CLK_INT		: in STD_LOGIC;
				CLR_R   		: in std_logic_vector(7 downto 0);
				CLR_G   		: in std_logic_vector(7 downto 0);
				CLR_B   		: in std_logic_vector(7 downto 0);
				CLR_WR  		: in std_logic;
				HPIX_CACHED	: out std_logic_vector(11 downto 0); 	-- 12 bit, but 10 is enought = 1024 pixels max
				VLIN_CACHED	: out std_logic_vector(11 downto 0); 	-- 12 bit, but 10 is enought = 1024 lines max
				SIG_DNEED	: out std_logic; 								-- Color Buffer Request
				DEBUG 		: out STD_LOGIC );
end gvif;

--
architecture Behavioral of gvif is

	signal	IFACE_HSYNC_OUT : std_logic;
	signal	IFACE_VSYNC_OUT : std_logic;
	
	signal STROBE_H_SYNC			: std_logic;
	 signal STROBE_H_BPORCH		: std_logic;
	 signal STROBE_H_VISIBLE	: std_logic;
	 signal STROBE_H_FPORCH		: std_logic;
	 signal STROBE_H_DE1			: std_logic;
	 signal STROBE_H_DE2			: std_logic;
	
	signal STROBE_V_SYNC 		: std_logic;
	 signal STROBE_V_BPORCH 	: std_logic;
	 signal STROBE_V_VISIBLE 	: std_logic;
	 signal STROBE_V_FPORCH  	: std_logic;
	 signal STROBE_V_DE1			: std_logic;
	 signal STROBE_V_DE2			: std_logic;

	signal SIGNAL_H_DE			: std_logic; -- 
	signal SIGNAL_V_DE			: std_logic; --	

	signal WINDOW_DEH				: std_logic;
	signal WINDOW_DEV				: std_logic;

	-- Limits enumeration / consts
	constant CONST_GVIF_HPIX_HSYNC   : STD_LOGIC_VECTOR(10 downto 0) := conv_std_logic_vector(94-1, 11);
	constant CONST_GVIF_HPIX_BPORCH  : STD_LOGIC_VECTOR(10 downto 0) := conv_std_logic_vector(94+124-1, 11);
	constant CONST_GVIF_HPIX_ACTIVE  : STD_LOGIC_VECTOR(10 downto 0) := conv_std_logic_vector(94+124+800-1,11);
	constant CONST_GVIF_HPIX_FPORCH  : STD_LOGIC_VECTOR(10 downto 0) := conv_std_logic_vector(94+124+800+36-1,11);
	constant CONST_GVIF_HPIX_DE1 		: STD_LOGIC_VECTOR(10 downto 0) := conv_std_logic_vector(94+64-1,11);				-- Data Enable  Area
	constant CONST_GVIF_HPIX_DE2 		: STD_LOGIC_VECTOR(10 downto 0) := conv_std_logic_vector(94+124+800+12-1,11);		-- Data Disable Area
	
	constant CONST_GVIF_VLIN_VSYNC  	: STD_LOGIC_VECTOR(9 downto 0) := conv_std_logic_vector(7-1,10);   				-- VSYNC Duration |__|
	constant CONST_GVIF_VLIN_BPORCH 	: STD_LOGIC_VECTOR(9 downto 0) := conv_std_logic_vector(7+21-1,10);				--
	constant CONST_GVIF_VLIN_ACTIVE 	: STD_LOGIC_VECTOR(9 downto 0) := conv_std_logic_vector(7+21+480-1,10); 		-- Visible Lines /~~~\
	constant CONST_GVIF_VLIN_FPORCH 	: STD_LOGIC_VECTOR(9 downto 0) := conv_std_logic_vector(7+21+480+17-1,10);  	-- ~~~###\_
	constant CONST_GVIF_VLIN_DE1		: STD_LOGIC_VECTOR(9 downto 0) := conv_std_logic_vector(24-1,10); 				-- During FP
	constant CONST_GVIF_VLIN_DE2		: STD_LOGIC_VECTOR(9 downto 0) := conv_std_logic_vector(490-1,10); 				-- During BP
	
	-- VIDEO H-MODE REGISTERS
	signal SETUP_H_SYNC		: std_logic_vector(10 downto 0);
	signal SETUP_H_BPORCH	: std_logic_vector(10 downto 0);
	signal SETUP_H_VISIBLE	: std_logic_vector(10 downto 0);
	signal SETUP_H_FPORCH 	: std_logic_vector(10 downto 0);
	signal SETUP_H_DE1		: std_logic_vector(10 downto 0);
	signal SETUP_H_DE2		: std_logic_vector(10 downto 0);
	
	-- VIDEO V-MODE REGISTERS
	signal SETUP_V_SYNC		: std_logic_vector(9 downto 0);
	signal SETUP_V_BPORCH	: std_logic_vector(9 downto 0);
	signal SETUP_V_VISIBLE	: std_logic_vector(9 downto 0);
	signal SETUP_V_FPORCH	: std_logic_vector(9 downto 0);
	signal SETUP_V_DE1		: std_logic_vector(9 downto 0);
	signal SETUP_V_DE2		: std_logic_vector(9 downto 0);

	--
	signal	GVIF_FLAGS8		: STD_LOGIC_VECTOR(7 downto 0);
	signal 	GVIF_MODE16		: STD_LOGIC; -- 16-bit/32-bit working mode

	signal 	GVIF_RESET  	: STD_LOGIC;
	signal	FIFOLESS32		: STD_LOGIC;

	-- ---------------
	-- SETUP VARIABLES
	-- ---------------
	signal CNT_SETUP_BYTE 			: STD_LOGIC_VECTOR(7 downto 0);
	signal WINDOW_EXTERNAL_DATAE 	: STD_LOGIC;

	-- Runtime
	signal GVIF_HPIX_CUR				: STD_LOGIC_VECTOR(11 downto 0);
	signal GVIF_VLIN_CUR				: STD_LOGIC_VECTOR(11 downto 0);
	
	-- Output Info
	signal GVIF_HPIX_REQUEST 		: STD_LOGIC_VECTOR(11 downto 0);
	signal GVIF_VLIN_REQUEST 		: STD_LOGIC_VECTOR(11 downto 0);	

	signal OLDSAMPLED_CLK33 		: std_logic;
	signal SAMPLED_CLK33				: std_logic;

	signal SAMPLED						: std_logic;
	signal SAMPLED_HSYNC				: std_logic;
	signal SAMPLED_VSYNC				: std_logic;
	signal SAMPLED_DEH 				: std_logic;
	signal SAMPLED_DEV 				: std_logic;
	signal SAMPLED_DNEED				: std_logic;

	signal SAMPLED_HSYNC_OLD 		: std_logic;
	signal SAMPLED_VSYNC_OLD 		: std_logic;

	signal FIFO_RESET					: std_logic;
	signal FIFO_RGB_IN 				: std_logic_vector(23 downto 0);
	signal FIFO_WR						: std_logic;
	signal FIFO_RDCNT					: std_logic_vector(5 downto 0);
	signal FIFO_RGB_OUT				: std_logic_vector(23 downto 0);	-- 33 Mhz / Read Pixel Value
	signal FIFO_RD						: std_logic; 							-- 33 Mhz / Read Pixel Pulse
	signal FIFO_RD2					: std_logic; 							-- Color Output / due to FIFO delay


	COMPONENT gvif_fifo
	PORT (
	rst 					: IN STD_LOGIC;
	wr_clk 				: IN STD_LOGIC;
	rd_clk 				: IN STD_LOGIC;
	din 					: IN STD_LOGIC_VECTOR(23 DOWNTO 0);
	wr_en 				: IN STD_LOGIC;
	rd_en 				: IN STD_LOGIC;
	dout 					: OUT STD_LOGIC_VECTOR(23 DOWNTO 0);
	full 					: OUT STD_LOGIC;
	empty 				: OUT STD_LOGIC;
	rd_data_count 		: OUT STD_LOGIC_VECTOR(5 DOWNTO 0);
	wr_data_count 		: OUT STD_LOGIC_VECTOR(5 DOWNTO 0) );
	END COMPONENT;

	signal	CLR_WROLD : std_logic;

begin

	-- Linkink GVIF RESET
	-- and GVIF_FLAGS8(0);
	GVIF_RESET		<= RESET;
	PIN_GVIF_CLK	<= not CLK33;

	--
	FIFO_RGB_IN(23 downto 16)  <= CLR_R;
	FIFO_RGB_IN(15 downto 8)	<= CLR_G;
	FIFO_RGB_IN(7 downto 0)		<= CLR_B;
	FIFO_WR 							<= CLR_WR;

	HPIX_CACHED		<= GVIF_HPIX_REQUEST;
	VLIN_CACHED 	<= GVIF_VLIN_REQUEST;
	
	--	--
	ints_gvf_fifo : gvif_fifo PORT MAP (
		rst 				=> FIFO_RESET,
		wr_clk 			=> CLK_INT,
		rd_clk			=> CLK33,
		din				=> FIFO_RGB_IN,
		wr_en				=> FIFO_WR,
		rd_en				=> FIFO_RD,	
		dout				=> FIFO_RGB_OUT,
		full 				=> open,
		empty 			=> open,
		rd_data_count 	=> FIFO_RDCNT,
		wr_data_count	=> open	);

--
gvfcore: process(CLK33,GVIF_RESET)
begin

 if GVIF_RESET='1' then 
	
	GVIF_HPIX_CUR 		<= (others=>'0');
	GVIF_VLIN_CUR 		<= (others=>'0');
	
	STROBE_H_SYNC 		<= '0';
	STROBE_H_BPORCH 	<= '0';
	STROBE_H_VISIBLE 	<= '0';
	STROBE_H_FPORCH 	<= '0';
	STROBE_H_DE1		<= '0';
	STROBE_H_DE2		<= '0';
	
	STROBE_V_SYNC		<= '0';
	STROBE_V_BPORCH	<= '0';
	STROBE_V_VISIBLE	<= '0';
	STROBE_V_FPORCH	<= '0';
	STROBE_V_DE1		<= '0';
	STROBE_V_DE2		<= '0';
	
	IFACE_HSYNC_OUT	<='0';
	IFACE_VSYNC_OUT	<='0';
	PIN_GVIF_HS			<='0';
	PIN_GVIF_VS			<='0';
	
	PIN_GVIF_R <= (others=>'0');
	PIN_GVIF_G <= (others=>'0');
	PIN_GVIF_B <= (others=>'0');
	
	PIN_GVIF_DE		<='0';
	PIN_GVIF_CTL	<='0';

	WINDOW_DEH	<='0';
	WINDOW_DEV	<='0';
	
	SIGNAL_H_DE<='0';
	SIGNAL_V_DE<='0';
	
	WINDOW_EXTERNAL_DATAE <= '0';
	
	FIFO_RESET	<= '1';
	FIFO_RD 		<= '0';
	FIFO_RD2		<= '0';
	
	FIFOLESS32  <= '0';
	
	DEBUG 		<= '0';
 
 elsif rising_edge(CLK33) then

	if GVIF_HPIX_CUR=SETUP_H_SYNC then 	
	STROBE_H_SYNC<='1';
	FIFO_RESET<='1';
	else
	STROBE_H_SYNC<='0';
	FIFO_RESET<='0';
	end if;
	
	if GVIF_HPIX_CUR=SETUP_H_BPORCH 	then	STROBE_H_BPORCH<='1';	else STROBE_H_BPORCH<='0'; 	end if;
	if GVIF_HPIX_CUR=SETUP_H_VISIBLE then 	STROBE_H_VISIBLE<='1';	else STROBE_H_VISIBLE<='0';	end if;
	if GVIF_HPIX_CUR=SETUP_H_FPORCH	then	STROBE_H_FPORCH<='1';	else STROBE_H_FPORCH<='0';		end if;
	if GVIF_HPIX_CUR=SETUP_H_DE1 		then	STROBE_H_DE1<='1';		else STROBE_H_DE1<='0';			end if;
	if GVIF_HPIX_CUR=SETUP_H_DE2 		then	STROBE_H_DE2<='1';		else STROBE_H_DE2<='0';			end if;
	if GVIF_HPIX_CUR=SETUP_H_FPORCH 	then 	GVIF_HPIX_CUR<=(others=>'0'); else GVIF_HPIX_CUR<=GVIF_HPIX_CUR+1; end if;

	if GVIF_VLIN_CUR=SETUP_V_SYNC 	and STROBE_H_FPORCH='1'	then STROBE_V_SYNC<='1';		else STROBE_V_SYNC<='0'; 	 end if;
	if GVIF_VLIN_CUR=SETUP_V_BPORCH 	and STROBE_H_FPORCH='1'	then STROBE_V_BPORCH<='1';		else STROBE_V_BPORCH<='0';	 end if;
	if GVIF_VLIN_CUR=SETUP_V_VISIBLE and STROBE_H_FPORCH='1'	then STROBE_V_VISIBLE<='1';	else STROBE_V_VISIBLE<='0'; end if;
	if GVIF_VLIN_CUR=SETUP_V_FPORCH	and STROBE_H_FPORCH='1'	then STROBE_V_FPORCH<='1';		else STROBE_V_FPORCH<='0';  end if;
	if GVIF_VLIN_CUR=SETUP_V_DE1		and STROBE_H_FPORCH='1'	then STROBE_V_DE1<='1';			else STROBE_V_DE1<='0';		 end if;
	if GVIF_VLIN_CUR=SETUP_V_DE2		and STROBE_H_FPORCH='1'	then STROBE_V_DE2<='1';			else STROBE_V_DE2<='0';		 end if;
	if GVIF_VLIN_CUR=SETUP_V_FPORCH	and STROBE_H_FPORCH='1'	then STROBE_V_FPORCH<='1';	 	else STROBE_V_FPORCH<='0';	 end if;

	-- V-Line counter
	if GVIF_HPIX_CUR=SETUP_H_FPORCH	then
	
		if GVIF_VLIN_CUR=CONST_GVIF_VLIN_FPORCH then
		GVIF_VLIN_CUR<=(others=>'0');
		else
		GVIF_VLIN_CUR<=GVIF_VLIN_CUR+1;
		end if;
		
	end if;

	-- HSYNC: Analizing strobes
	if STROBE_H_SYNC='1' 	then
	IFACE_HSYNC_OUT<='1';
	PIN_GVIF_HS<='1';
	elsif STROBE_H_FPORCH='1' then
	IFACE_HSYNC_OUT<='0';
	PIN_GVIF_HS<='0';
	end if;

	-- VSYNC: Analizing strobes
	if STROBE_V_SYNC='1' then
	IFACE_VSYNC_OUT	<='1';
	PIN_GVIF_VS			<='1';
	elsif STROBE_V_FPORCH='1' then 
	IFACE_VSYNC_OUT	<='0';
	PIN_GVIF_VS			<='0';
	end if; 
	
	if STROBE_H_SYNC='1' 	then WINDOW_EXTERNAL_DATAE<='1'; elsif STROBE_H_FPORCH='1'	then WINDOW_EXTERNAL_DATAE<='0'; end if;
	if STROBE_H_BPORCH='1' 	then WINDOW_DEH<='1'; 				elsif STROBE_H_VISIBLE='1'	then WINDOW_DEH<='0'; 				end if; -- HSYNC: Color enable
	if STROBE_V_BPORCH='1'	then WINDOW_DEV<='1';				elsif STROBE_V_VISIBLE='1' then WINDOW_DEV<='0'; 				end if; -- VSYNC: Visible Area
	if STROBE_H_DE1='1' 		then SIGNAL_H_DE<='1'; 				elsif STROBE_H_DE2='1' 		then SIGNAL_H_DE<='0'; 				end if;
	if STROBE_V_DE1='1' 		then SIGNAL_V_DE<='1'; 				elsif STROBE_V_DE2='1' 		then SIGNAL_V_DE<='0'; 				end if;
	
	if WINDOW_DEV='1' and WINDOW_DEH='1' then 
	FIFO_RD <= '1';
	else
	FIFO_RD <= '0';
	end if;
	
	FIFO_RD2 <= FIFO_RD;
	
	if FIFO_RD2='1' then 
	PIN_GVIF_R <= FIFO_RGB_OUT(23 downto 16);
	PIN_GVIF_G <= FIFO_RGB_OUT(15 downto 8);
	PIN_GVIF_B <= FIFO_RGB_OUT(7 downto 0);
	else
	PIN_GVIF_R <= (others=>'0');
	PIN_GVIF_G <= (others=>'0');
	PIN_GVIF_B <= (others=>'0');
	end if;
	 
	-- Data enable strobe control
	PIN_GVIF_DE <= SIGNAL_H_DE and SIGNAL_V_DE;

	-- FIFO Empty ?
	if FIFO_RDCNT<32 then 
	FIFOLESS32  <= '1';
	else
	FIFOLESS32  <= '0';
	end if;

 end if; -- rising edge
 
end process;

-- 133 Mhz IFACE Info
synchro_info: process(CLK_INT,RESET)
begin

 if RESET='1' then

	SIG_DNEED			<= '0';

	GVIF_HPIX_REQUEST <= (others=>'0');
	GVIF_VLIN_REQUEST	<= (others=>'0');

	SAMPLED 				<= '0';
	SAMPLED_CLK33 		<= '0';
	OLDSAMPLED_CLK33 	<= '0';

	SAMPLED_HSYNC		<= '0';
	SAMPLED_VSYNC		<= '0';
	SAMPLED_DNEED		<= '0';
	SAMPLED_DEH			<= '0';
	SAMPLED_DEV			<= '0';
	
	SAMPLED_HSYNC_OLD <= '0';
	SAMPLED_VSYNC_OLD <= '0';
	
	CLR_WROLD <= '0';

 elsif rising_edge(CLK_INT) then

	SAMPLED_CLK33 		<= CLK33;
	OLDSAMPLED_CLK33 	<= SAMPLED_CLK33;
	
	--
	if SAMPLED_CLK33='1' and OLDSAMPLED_CLK33='0' then
		SAMPLED 			<= '1';
		
		SAMPLED_DNEED	<= FIFOLESS32;
		SAMPLED_HSYNC	<= IFACE_HSYNC_OUT;
		SAMPLED_VSYNC	<= IFACE_VSYNC_OUT;
		SAMPLED_DEH		<= WINDOW_DEH;
		SAMPLED_DEV		<= WINDOW_DEV;
	else
		SAMPLED		<= '0';
	end if;
	
	--
	SAMPLED_HSYNC_OLD <= SAMPLED_HSYNC;
	SAMPLED_VSYNC_OLD <= SAMPLED_VSYNC;
	CLR_WROLD <= CLR_WR;
	
	-- 1) SIG_DNEED
	-- 2) GVIF_HPIX_REQUEST
	-- 3) GVIF_VLIN_REQUEST

	if CLR_WR='1' and CLR_WROLD='0' then
		GVIF_HPIX_REQUEST<=GVIF_HPIX_REQUEST+8;
	else
		
		-- ="000" and GVIF_HPIX_REQUEST(11 downto 3)<64 and 
		if GVIF_HPIX_REQUEST<800 and SAMPLED_DNEED='1' and SAMPLED_HSYNC='1' and SAMPLED_DEV='1' then
		SIG_DNEED <= '1';
		else
		SIG_DNEED <= '0';
		end if;
		
		if SAMPLED='1' and SAMPLED_HSYNC='0' then
		GVIF_HPIX_REQUEST<=(others=>'0');
		end if;
		
		if SAMPLED_DEV='0' then
		GVIF_VLIN_REQUEST <= (others=>'0');
		elsif SAMPLED_HSYNC='0' and SAMPLED_HSYNC_OLD='1' then
		GVIF_VLIN_REQUEST <= GVIF_VLIN_REQUEST+1;
		end if;
	
	end if;
		
 
 end if; -- rising_edge 

end process;

-- -------------------------------------------------------
-- Setup
-- -------------------------------------------------------
setup: process(SETUP_CLK,RESET)
begin
 if RESET='1' then
  
  CNT_SETUP_BYTE <= (others=>'0');

  GVIF_FLAGS8 <= (others=>'1');
  
  SETUP_H_FPORCH	<= CONST_GVIF_HPIX_FPORCH;
  SETUP_H_SYNC 	<= CONST_GVIF_HPIX_HSYNC;
  SETUP_H_BPORCH 	<= CONST_GVIF_HPIX_BPORCH;
  SETUP_H_VISIBLE <= CONST_GVIF_HPIX_ACTIVE;
  SETUP_H_DE1 		<= CONST_GVIF_HPIX_DE1;
  SETUP_H_DE2 		<= CONST_GVIF_HPIX_DE2;

  SETUP_V_FPORCH	<= CONST_GVIF_VLIN_FPORCH;
  SETUP_V_SYNC		<= CONST_GVIF_VLIN_VSYNC;
  SETUP_V_BPORCH	<= CONST_GVIF_VLIN_BPORCH;
  SETUP_V_VISIBLE <= CONST_GVIF_VLIN_ACTIVE;
  SETUP_V_DE1		<= CONST_GVIF_VLIN_DE1;
  SETUP_V_DE2		<= CONST_GVIF_VLIN_DE2;

 elsif rising_edge(SETUP_CLK) then

  if SETUP_CLR='1' then
   CNT_SETUP_BYTE <= (others=>'0');
  elsif SETUP_WR='1' then
   CNT_SETUP_BYTE <= CNT_SETUP_BYTE+1;
   
	case CNT_SETUP_BYTE is
   	
		when x"00" => null;
		when x"01" => null;
		when x"02" => null;
		when x"03" => null;
		
		when x"04" => null;
		when x"05" => null;
		when x"06" => null;
		when x"07" => null;
		
		when x"08" => GVIF_FLAGS8 <= SETUP_BUS;
		when x"09" => null;
		
		when x"0A" => SETUP_H_FPORCH(10 downto 8) 	<= SETUP_BUS(2 downto 0);
		when x"0B" => SETUP_H_FPORCH(7 downto 0) 		<= SETUP_BUS;
		
		when x"0C" => SETUP_H_SYNC(10 downto 8) 		<= SETUP_BUS(2 downto 0);
		when x"0D" => SETUP_H_SYNC(7 downto 0) 		<= SETUP_BUS;
		
		when x"0E" => SETUP_H_BPORCH(10 downto 8)		<= SETUP_BUS(2 downto 0);
		when x"0F" => SETUP_H_BPORCH(7 downto 0)		<= SETUP_BUS;
		
		when x"10" => SETUP_H_VISIBLE(10 downto 8)	<= SETUP_BUS(2 downto 0);
		when x"11" => SETUP_H_VISIBLE(7 downto 0)		<= SETUP_BUS;
		
		when x"12" => SETUP_H_DE1(10 downto 8)			<= SETUP_BUS(2 downto 0);
		when x"13" => SETUP_H_DE1(7 downto 0)			<= SETUP_BUS;
		
		when x"14" => SETUP_H_DE2(10 downto 8)			<= SETUP_BUS(2 downto 0);
		when x"15" => SETUP_H_DE2(7 downto 0)			<= SETUP_BUS;
		
		when x"16" => SETUP_V_FPORCH(9 downto 8)  	<= SETUP_BUS(1 downto 0);
		when x"17" => SETUP_V_FPORCH(7 downto 0)  	<= SETUP_BUS;
		
		when x"18" => SETUP_V_SYNC(9 downto 8)			<= SETUP_BUS(1 downto 0);
		when x"19" => SETUP_V_SYNC(7 downto 0)  		<= SETUP_BUS;
		
		when x"1A" => SETUP_V_BPORCH(9 downto 8)		<= SETUP_BUS(1 downto 0);
		when x"1B" => SETUP_V_BPORCH(7 downto 0)  	<= SETUP_BUS;
		
		when x"1C" => SETUP_V_VISIBLE(9 downto 8)		<= SETUP_BUS(1 downto 0);
		when x"1D" => SETUP_V_VISIBLE(7 downto 0) 	<= SETUP_BUS;
		
		when x"1E" => SETUP_V_DE1(9 downto 8)			<= SETUP_BUS(1 downto 0);
		when x"1F" => SETUP_V_DE1(7 downto 0) 			<= SETUP_BUS;
		
		when x"20" => SETUP_V_DE2(9 downto 8)			<= SETUP_BUS(1 downto 0);
		when x"21" => SETUP_V_DE2(7 downto 0) 			<= SETUP_BUS;

		when others=> null;
		
   end case;
  end if;
 end if;
end process;

end Behavioral;



