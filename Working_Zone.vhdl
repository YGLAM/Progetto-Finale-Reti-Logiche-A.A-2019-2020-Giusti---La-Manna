----------------------------------------------------------------------------------
-- Studente: Giuseppe La Manna Leonardo Giusti
-- Codice Matricola : 10608466
-- Design Name: 
-- Module Name: project_reti_logiche - Behavioral
--
-- Description: A module that encodes addresses for a RAM using Working Zones
-- Revision 0.02 - Notepad++ version
--
-- Additional Comments:
----------------------------------------------------------------------------------

--TODO:
-- Verifica se i segnali presenti nella sensitivity_list di lambda sono tutti necessario
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.std_logic_unsigned.all;
use IEEE.NUMERIC_STD.ALL;
package constants is 
	constant ram_in_address : std_logic_vector := "0000000000001000";
	constant ram_out_address : std_logic_vector := "0000000000001001";
end constants;

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.std_logic_unsigned.all;
use IEEE.NUMERIC_STD.ALL;
use work.constants.all;

entity project_reti_logiche is
	port(
		i_clk : in std_logic;
		i_start : in std_logic; 
		i_rst : in std_logic;
		i_data : in std_logic_vector ( 7 downto 0 );
		o_address : out std_logic_vector ( 15 downto 0 );
		o_done : out std_logic ;
		o_en : out std_logic ; 
		o_we : out std_logic ; 
		o_data : out std_logic_vector ( 7 downto 0 )
);
end entity;

architecture behavioral of project_reti_logiche is 
	--enum degli stati della FSM
	type state_type is( idle , wait_address, get_address ,wz_loop,get_wz,wait_wz,check_wz,calc_address,output_address,wait_done,done,reset);
	--type loaded_wz is array( 7 downto 0 ) of std_logic_vector ( 7 downto 0) ;
	
	signal current_state, next_state : state_type;
	--segnale contenente l'address base della working zone corrispondente
	signal current_wz,    next_wz    :std_logic_vector ( 7 downto 0 ) ;--: loaded_wz; 
	--segnali per il successivo valore degli output
	signal o_done_next, o_en_next, o_we_next    : std_logic := '0';
	signal o_data_next : std_logic_vector(7 downto 0)     := "00000000";
	signal o_address_next : std_logic_vector(15 downto 0) := "0000000000000000";
	
	--su di lui salvo temporaneamente il valore dell'indirizzo richiesto da RAM[8]
	signal read_address, read_address_next : std_logic_vector( 7 downto 0) := "00000000";
	--segnale che specifica se il read_address appartiene  o meno alla working zone
	signal does_belong , does_belong_next : std_logic := '0'; 
	--segnale contenente il numero della working zone cui si riferisce l'address ricevuto da RAM[8]
	signal wz_num , wz_num_next : integer range 0 to 7 := 0;
	--segnale contenente l'offset dell'address di RAM[8] rispetto alla base della working zone 
	--signal wz_off , wz_off_next : std_logic_vector ( 3 downto 0 ) := "0000";
	--segnale finale codificato che andrò a scrivere su RAM[9]
	signal coded_address , coded_address_next : std_logic_vector ( 7 downto 0 ) := "00000000";
	
	signal need_rst : boolean := false; 
	
	begin         
	   reset_change: process ( i_rst,current_state) 
	    begin   
	       if rising_edge( i_rst) then 
	           need_rst <= true;
	       end if;
	      if ( current_state = reset) then
	           need_rst <= false;    
	       end if;
	    end process;   
		
		state_change : process ( i_clk) 
            begin   
                if rising_edge(i_clk) then
				    --scorro i miei output al valore successivo
				    if ( need_rst = false ) then
				        current_state   <= next_state;
				    
					   current_wz      <= next_wz;
				   
				        o_done          <= o_done_next;
				        o_en            <= o_en_next;
				        o_we            <= o_we_next;
				        o_data          <= o_data_next;
				        o_address       <= o_address_next;
				    
				        read_address    <= read_address_next;
				        does_belong     <= does_belong_next;
				        wz_num          <= wz_num_next;
				    
					   coded_address   <= coded_address_next;
			        elsif ( need_rst = true ) then
			           			           
			           current_state        <= reset;	
			        end if;  
			  end if;  
		end process;
		
		--potrebbe essere necessario cambiare la sensitivity list
		lambda : process ( i_rst, i_start,i_data,current_state,current_wz,read_address,coded_address,does_belong,wz_num) 
		  variable wz_num_vector : unsigned( 2 downto 0 ) := "000";
		  variable wz_off : unsigned  (3 downto 0) := "0000";
		  begin 
			--inizializzo i valori dei registri next per l'output, se non vengono modificati permangono nel loro stato 
			next_state           <= current_state;
			next_wz              <= current_wz; 
						
			o_done_next    <= '0';
			o_en_next      <= '0';
			o_we_next      <= '0';
			o_data_next    <= "00000000";
			o_address_next <= "0000000000000000";
			
			read_address_next    <= read_address;
			does_belong_next     <= does_belong;			
			wz_num_next          <= wz_num ;
			--wz_off               := "0000";
			
			coded_address_next   <= coded_address;
			
			
			case current_state is
				--stato di attesa per il segnale di start
				when idle =>
					if i_start = '1' then 
						next_state <= wait_address;
						o_en_next <= '1';
					    o_we_next <= '0';
					
					   o_address_next <= ram_in_address;--RAM[8]
					end if;
				  
				--stato in cui richiedo alla RAM l'address da codificare presente in RAM[8] 
				when wait_address => 
					next_state     <= get_address; 
				
				--stato in cui ottengo l'address da codificare da RAM[8] e lo salvo in memoria
				when get_address =>
					
					read_address_next <= i_data;
					next_state <= wz_loop; 
				   -- o_data_next <= i_data;--print
				--stato in cui verifico se ho controllato tutte le working zone, continuo fino a quando non le ho viste tutte o l'address appartiene ad una
				when wz_loop => 
					
					--o_data_next <= read_address;--print
						--mi prendo il valore RAM[number_wz] 
						o_en_next      <= '1';
						o_we_next      <= '0';
						o_address_next <= std_logic_vector (to_unsigned(wz_num_next,o_address_next'length));
						--passo allo slot successivo 
						next_state <= wait_wz;
				when wait_wz =>
						--o_data_next <= read_address;
				        next_state     <= get_wz;
				--carico l'address base della working zone 	
				when get_wz =>
					  -- case wz_num_next is --start print 
			           -- when 0 =>
			               --  o_address_next <= "0001000000000000";
			                --  when 1 =>
			                -- o_address_next <= "0001100000000000";
			                --      when 2 =>
			                -- o_address_next <= "0001010000000000";
			                --      when 3 =>
			                -- o_address_next <= "0001001000000000";
			                 --     when 4 =>
			                 --o_address_next <= "0001000100000000";
			                --      when 5 =>
			               -- o_address_next <= "0001000010000000";
			              --        when 6 =>
			              --   o_address_next <= "0001000001000000";
			               --       when 7 =>
			               --  o_address_next <= "0001000000100000"; 
			      --  end case; -- end print
					next_wz    <= i_data; 
					next_state <= check_wz;
				--controllo se l'address appartiene o meno ad una working zone e capisco se devo continuare a scorrere o se passare alla costruzione dell'address finale	
				when check_wz => 
			       -- o_data_next <= current_wz;              
			        if ( to_integer(unsigned(read_address)) >= to_integer(unsigned(current_wz)) and to_integer(unsigned(read_address)) <= ( to_integer(unsigned(current_wz))+3)) then
						does_belong_next <= '1';
						--o_address_next <= "0011000000000000";--print
						next_state       <= calc_address; 
					elsif (wz_num < 7 ) then 
						wz_num_next        <= wz_num+1;
  					--o_address_next <= "0101000000000000";--print
                        next_state <= wz_loop;
					else 
						--o_address_next <= "1001000000000000";--print
						next_state   <= calc_address;
					end if;
				    
			  
				-- stato in cui calcolo l'address in base alla sua appartenenza o meno ad una working zone	
				when calc_address =>
				    
				    --codifica one-hot per address 
					if ( does_belong = '1' ) then 
						--calcolo il numero della wz e il suo offset
						wz_off      := (others => '0');
						wz_off(to_integer(unsigned(read_address) - unsigned(current_wz))) := '1';
						wz_num_vector := to_unsigned(wz_num_next, wz_num_vector'length);
						coded_address_next <= '1' & std_logic_vector(wz_num_vector) & std_logic_vector(wz_off);
					
					elsif ( does_belong = '0') then
						coded_address_next <= read_address_next;
					end if;
				o_data_next <= read_address_next;
					next_state <= output_address;
				--stato in cui scrivo in memoria il valore finale dell'address in memoria
				when output_address =>
					o_en_next      <= '1';
					o_we_next      <= '1';
					o_address_next <=ram_out_address;
					o_data_next <= coded_address;
					
					
					next_state <= wait_done;
				--stato di completamento in cui attendo un nuovo segnale di start
				when wait_done =>
				    o_address_next(7 downto 0) <= i_data;
					o_data_next <= coded_address_next;
					o_done_next <='1';
				    next_state <= done;
				when done => 
				o_data_next <= read_address_next;

					if ( i_start = '0') then 
						o_done_next          <= '0';	
						
						read_address_next    <= "00000000";
						coded_address_next   <= "00000000";
						next_wz              <= "00000000";
						wz_num_next          <= 0;
						wz_off               := "0000";
						
						does_belong_next          <= '0';
						next_state           <= idle;
					end if;
				when reset =>
				                 
					next_wz			 <= "00000000";
			
				    read_address_next         <= "00000000";
				    does_belong_next          <= '0' ;
				    wz_num_next               <= 0;
				    wz_off                    := "0000";
				    
					coded_address_next        <= "00000000";
					next_state <= idle; 
			end case; 
		end process; 
end behavioral;