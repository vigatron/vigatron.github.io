----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    09:42:54 02/02/2012 
-- Design Name: 
-- Module Name:    SAF7113 - Behavioral 
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
-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
-- use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
-- library UNISIM;
-- use UNISIM.VComponents.all;

entity SAF7113 is
    Port ( 
		CLK : in  STD_LOGIC;
		RESET : in  STD_LOGIC;
           
		CFG_CLK : in  STD_LOGIC;
		CFG_CLR : in  STD_LOGIC;
		CFG_DAT : in  STD_LOGIC_VECTOR (7 downto 0);
		CFG_WR : in  STD_LOGIC;

		PALNOS_BUS : in  STD_LOGIC_VECTOR (7 downto 0);
		PALNOS_CLK : in  STD_LOGIC;
		PALNOS_CTL : in  STD_LOGIC_VECTOR(2 downto 0);
		
		OUT_BUS 	: out  STD_LOGIC_VECTOR (31 downto 0);
		OUT_RD 	: in 	 STD_LOGIC;
		OUT_CNT	: out	 STD_LOGIC_VECTOR(4 downto 0);
		
		OUT_HSYNC : out std_logic;
		OUT_VSYNC : out std_logic;
		
		DEBUG : out  STD_LOGIC_VECTOR(3 downto 0) );
		
end SAF7113;

architecture Behavioral of SAF7113 is
	
	signal	PAL_CTL : STD_LOGIC_VECTOR(2 downto 0);
	signal	PAL_CLK : STD_LOGIC;
	signal	PAL_BUS : STD_LOGIC_VECTOR(7 downto 0);
	
	signal 	PAL_CLK_OLD : std_logic;

	--
	signal	VALID_TCODE_SIG	: std_logic;
	signal	VALID_YUW_SIG		: std_logic;

	signal	TCODE_BUS			: std_logic_vector(7 downto 0);
	signal 	TCODE_CNT			: std_logic_vector(1 downto 0);
	
	signal 	YUV_ACT	 		: std_logic;
	signal	YUW_BUS			: std_logic_vector(7 downto 0);
	signal	YUW_CNT			: std_logic_vector(1 downto 0);
	
	-- Runtime values
	signal	RUN_CB 	: std_logic_vector(7 downto 0);
	signal	RUN_Y0	: std_logic_vector(7 downto 0);
	signal	RUN_CR	: std_logic_vector(7 downto 0);
	signal	RUN_Y1	: std_logic_vector(7 downto 0);
	
	-- Color calculation variables
	signal	Y0	: std_logic_vector(7 downto 0);
	signal	CR	: std_logic_vector(7 downto 0);
	signal	CB : std_logic_vector(7 downto 0);

	signal	VALID_PXL_SIG		: std_logic;
	signal	VALID_PXL_SIG_OLD	: std_logic;
	signal	DO_RGB				: std_logic;
	signal	SAVE_RGB				: std_logic;
	signal	RGB_DONE_SIG   	: std_logic;
	
	signal	FINR : std_logic_vector(7 downto 0);
	signal	FING : std_logic_vector(7 downto 0);
	signal	FINB : std_logic_vector(7 downto 0);
	
	signal	HSYNC	: std_logic;
	signal	VSYNC : std_logic;
	
	--
   COMPONENT fifo_saf7113
   PORT( clk : IN  std_logic;
         srst : IN  std_logic;
         din : IN  std_logic_vector(31 downto 0);
         wr_en : IN  std_logic;
         rd_en : IN  std_logic;
         dout : OUT  std_logic_vector(31 downto 0);
         full : OUT  std_logic;
         empty : OUT  std_logic;
         data_count : OUT  std_logic_vector(4 downto 0) );
   END COMPONENT;

	signal	PAL_RESULT_PUTBUS : std_logic_vector(31 downto 0);
	signal	PAL_RESULT_WR		: std_logic;

begin

	saf_fifo: fifo_saf7113 PORT MAP (
          clk 	=> CLK,
          srst => RESET,
          
			 din => 		PAL_RESULT_PUTBUS,
          wr_en => 	PAL_RESULT_WR,
          
			 rd_en => 		OUT_RD,
          dout => 		OUT_BUS,
          full => 		open,
          empty => 		open,
          data_count => OUT_CNT );


PAL_RESULT_PUTBUS(16) <= '0';
PAL_RESULT_PUTBUS(0) <= '0';

--
sync: process(CLK,RESET)
begin

 if RESET='1' then
	
		PAL_CLK	<= '0';
		PAL_CTL	<= (others=>'0');
	
		PAL_CLK_OLD	<= '0';
		
		PAL_BUS		<= (others=>'0');

		TCODE_BUS<=(others=>'0');
		TCODE_CNT<=(others=>'1');
	
		YUV_ACT	<= '0';
		YUW_BUS  <= (others=>'0');
		YUW_CNT	<= (others=>'0');
	
		RUN_CB	<= (others=>'0');
		RUN_Y0	<= (others=>'0');
		RUN_CR	<= (others=>'0');
		RUN_Y1	<= (others=>'0');

		FINR <= (others=>'0');
		FING <= (others=>'0');
		FINB <= (others=>'0');
	
		VALID_TCODE_SIG	<='0';
		
		VALID_PXL_SIG		<='0';
		VALID_PXL_SIG_OLD	<='0';
		
		VALID_YUW_SIG		<='0';
		RGB_DONE_SIG		<='0';
		PAL_RESULT_WR 		<='0';
		DO_RGB 				<='0';
		SAVE_RGB				<='0';
	
		HSYNC <='1';
		VSYNC	<='1';
		
		OUT_HSYNC <= '0';
		OUT_VSYNC <= '0';
 
		DEBUG <= (others=>'0');
 
 elsif rising_edge(CLK) then

	-- DEBUG
	DEBUG(0) <= VALID_TCODE_SIG;
	DEBUG(1) <= VALID_YUW_SIG;

	-- INPUTS Synchronization
	PAL_CTL		<=	PALNOS_CTL;
	PAL_BUS		<=	PALNOS_BUS;
	PAL_CLK		<= not PALNOS_CLK;

	-- Used for Edge Detection
	PAL_CLK_OLD <= PAL_CLK;
	
	-- Catch byte on PALCLK Rising edge
	if PAL_CLK='1' and PAL_CLK_OLD='0' then
		
		if PAL_BUS=x"FF" then
		TCODE_BUS			<=PAL_BUS;
		VALID_TCODE_SIG	<='1';
		TCODE_CNT			<= (others=>'0');
		else
			
				if TCODE_CNT/="11" then
				TCODE_BUS			<= PAL_BUS;
				TCODE_CNT			<= TCODE_CNT+1;
				VALID_TCODE_SIG	<= '1';
				else				
				
					if YUV_ACT='1' then
					YUW_BUS 				<= PAL_BUS;
					VALID_YUW_SIG		<= '1';
					end if;
					
				end if;
		
		end if;
		
	else 
		VALID_TCODE_SIG	<='0';
		VALID_YUW_SIG		<='0';
	end if;

	-- Processing TIMECODE
	if VALID_TCODE_SIG='1' then
	
		if TCODE_CNT="11" then
		YUV_ACT<=not TCODE_BUS(4);
		HSYNC		<= TCODE_BUS(4);
		DEBUG(2) <= TCODE_BUS(4);
		
		VSYNC 	<= TCODE_BUS(5);
		DEBUG(3) <= TCODE_BUS(5);
		end if;
	
	else
		HSYNC		<= '0';
	end if;
	
	--
	OUT_HSYNC 	<= HSYNC;
	OUT_VSYNC	<= VSYNC;

	-- YUW_CNT
	if VALID_TCODE_SIG='1' then
	YUW_CNT	<= (others=>'0');
	elsif VALID_YUW_SIG='1' then
	YUW_CNT	<= YUW_CNT+1;
	end if;

	-- Visible
	if VALID_YUW_SIG='1' then
			
			case YUW_CNT is
			when "00" => RUN_CB <= YUW_BUS - x"80"; VALID_PXL_SIG	<='0';
			when "01" => RUN_Y0 <= YUW_BUS - x"10"; VALID_PXL_SIG	<='0';
			when "10" => RUN_CR <= YUW_BUS - x"80"; VALID_PXL_SIG <='0'; 
			when "11" => RUN_Y1 <= YUW_BUS - x"10"; VALID_PXL_SIG	<='1';
			when others=> null;
			end case;
	else
		VALID_PXL_SIG <= '0';
	end if;
	
	VALID_PXL_SIG_OLD <= VALID_PXL_SIG;
	
	-- 
	if VALID_PXL_SIG='1' then
		Y0 <= RUN_Y0;
		CR <= RUN_CR;
		CB <= RUN_CB;
		DO_RGB<='1';
		SAVE_RGB<='0';
	elsif VALID_PXL_SIG_OLD='1' then
		Y0 <= RUN_Y1;
		CR <= RUN_CR;
		CB <= RUN_CB;
		DO_RGB <= '1';
		SAVE_RGB<='1';
	else
		DO_RGB <= '0';
		SAVE_RGB<='0';
	end if;
	
	--
	if DO_RGB='1' then
		
				FINR <= (Y0 + CR) + (CR(7)&CR(7)&(CR(7 downto 2)+(CR(7)&CR(7 downto 3))+(CR(7)&CR(7)&CR(7)&CR(7 downto 5))));
				
				FING <= Y0 - (
				(CB(7)& CB(7)& ((CB(7 downto 2))	+
				(CB(7)&CB(7)&CB(7 downto 4))+
				(CB(7)&CB(7)&CB(7)&CB(7 downto 5))))
				+
				(CR(7)&((CR(7 downto 1)) +	
				(CR(7)&CR(7)&CR(7 downto 3))+ 
				(CR(7)&CR(7)&CR(7)&CR(7 downto 4))+
				(CR(7)&CR(7)&CR(7)&CR(7)&CR(7 downto 5)))) );

				FINB <= (Y0 + CB) + (CB(7)&CB(7 downto 1)+(CB(7)&CB(7 downto 2))+(CB(7)&CB(7)&CB(7)&CB(7)&CB(7)&CB(7 downto 6)));
				
				RGB_DONE_SIG <='1';
	else
				RGB_DONE_SIG <='0';
	end if;
	
	if RGB_DONE_SIG='1' then
	
		if SAVE_RGB='0' then
		PAL_RESULT_PUTBUS(31 downto 27) <= FINR(7 downto 3);
		PAL_RESULT_PUTBUS(26 downto 22) <= FING(7 downto 3);
		PAL_RESULT_PUTBUS(21 downto 17) <= FINB(7 downto 3);
		PAL_RESULT_WR <= '0';
		else
		PAL_RESULT_PUTBUS(15 downto 11) <= FINR(7 downto 3);
		PAL_RESULT_PUTBUS(10 downto 6 ) <= FING(7 downto 3);
		PAL_RESULT_PUTBUS(5  downto 1 ) <= FINB(7 downto 3);
		-- PAL_RESULT_WR <= '1';
		end if;
		
	else
		PAL_RESULT_WR <= '0';
	end if;

 end if; -- rising edge

end process;

end Behavioral;

-- int Y  = trackBar1->Value - 16;
-- int Cr = trackBar2->Value - 128;
-- int Cb = trackBar3->Value - 128;

-- int r = Y + Cr + (Cr>>2)+(Cr>>3)+(Cr>>5);
-- int g = Y - ((Cb>>2)+(Cb>>4)+(Cb>>5)) - ((Cr>>1)+(Cr>>3)+(Cr>>4)+(Cr>>5));
-- int b = Y + Cb + (Cb>>1) + (Cb>>2) + (Cb>>6);

-- r = r & 0xFF;
-- g = g & 0xFF;
-- b = b & 0xFF;


