	component sram is
		port (
			clk           : in    std_logic                     := 'X';             -- clk
			reset         : in    std_logic                     := 'X';             -- reset
			SRAM_DQ       : inout std_logic_vector(15 downto 0) := (others => 'X'); -- DQ
			SRAM_ADDR     : out   std_logic_vector(19 downto 0);                    -- ADDR
			SRAM_LB_N     : out   std_logic;                                        -- LB_N
			SRAM_UB_N     : out   std_logic;                                        -- UB_N
			SRAM_CE_N     : out   std_logic;                                        -- CE_N
			SRAM_OE_N     : out   std_logic;                                        -- OE_N
			SRAM_WE_N     : out   std_logic;                                        -- WE_N
			address       : in    std_logic_vector(19 downto 0) := (others => 'X'); -- address
			byteenable    : in    std_logic_vector(1 downto 0)  := (others => 'X'); -- byteenable
			read          : in    std_logic                     := 'X';             -- read
			write         : in    std_logic                     := 'X';             -- write
			writedata     : in    std_logic_vector(15 downto 0) := (others => 'X'); -- writedata
			readdata      : out   std_logic_vector(15 downto 0);                    -- readdata
			readdatavalid : out   std_logic                                         -- readdatavalid
		);
	end component sram;

	u0 : component sram
		port map (
			clk           => CONNECTED_TO_clk,           --                clk.clk
			reset         => CONNECTED_TO_reset,         --              reset.reset
			SRAM_DQ       => CONNECTED_TO_SRAM_DQ,       -- external_interface.DQ
			SRAM_ADDR     => CONNECTED_TO_SRAM_ADDR,     --                   .ADDR
			SRAM_LB_N     => CONNECTED_TO_SRAM_LB_N,     --                   .LB_N
			SRAM_UB_N     => CONNECTED_TO_SRAM_UB_N,     --                   .UB_N
			SRAM_CE_N     => CONNECTED_TO_SRAM_CE_N,     --                   .CE_N
			SRAM_OE_N     => CONNECTED_TO_SRAM_OE_N,     --                   .OE_N
			SRAM_WE_N     => CONNECTED_TO_SRAM_WE_N,     --                   .WE_N
			address       => CONNECTED_TO_address,       --  avalon_sram_slave.address
			byteenable    => CONNECTED_TO_byteenable,    --                   .byteenable
			read          => CONNECTED_TO_read,          --                   .read
			write         => CONNECTED_TO_write,         --                   .write
			writedata     => CONNECTED_TO_writedata,     --                   .writedata
			readdata      => CONNECTED_TO_readdata,      --                   .readdata
			readdatavalid => CONNECTED_TO_readdatavalid  --                   .readdatavalid
		);

