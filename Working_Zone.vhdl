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
-- Stima se è necessario passare ad un sistema con un solo process 

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
	type state_type is( idle , fetch_address, get_address ,wz_loop,get_wz,check_wz,calc_address,output_address,done);
	--type loaded_wz is array( 7 downto 0 ) of std_logic_vector ( 7 downto 0) ;
	
	signal current_state, next_state : state_type;
	--segnale contenente l'address base della working zone corrispondente
	signal current_wz,    next_wz    :std_logic_vector ( 7 downto 0 ) ;--: loaded_wz; 
	--segnale contenente l'address corrente che sto richiedendo dalla RAM 
	signal address_request,address_request_next :std_logic_vector ( 15 downto 0) := "0000000000000000"; 
	--segnali per il successivo valore degli output
	signal o_done_next, o_en_next, o_we_next    : std_logic := '0';
	signal o_data_next : std_logic_vector(7 downto 0)     := "00000000";
	signal o_address_next : std_logic_vector(15 downto 0) := "0000000000000000";
	
	--su di lui salvo temporaneamente il valore dell'indirizzo richiesto da RAM[8]
	signal read_address, read_address_next : std_logic_vector( 7 downto 0) := "00000000";
	--segnale che specifica se il read_address appartiene  o meno alla working zone
	signal does_belong , does_belong_next : std_logic := '0'; 
	--segnale contenente il numero della working zone cui si riferisce l'address ricevuto da RAM[8]
	signal wz_num , wz_num_next : std_logic_vector ( 2 downto 0 ) := "000";
	--segnale contenente l'offset dell'address di RAM[8] rispetto alla base della working zone 
	signal wz_off , wz_off_next : std_logic_vector ( 3 downto 0 ) := "0000";
	--segnale finale codificato che andrò a scrivere su RAM[9]
	signal coded_address , coded_address_next : std_logic_vector ( 7 downto 0 ) := "00000000";
	
	--signal got_address , got_address_next : boolean := false 
	
	begin 
		state_change : process ( i_clk, i_rst ) 
		begin 
		
			if (rising_edge(i_rst)) then
				current_wz      <= "00000000";
			
				address_request <= "0000000000000000"; 
				read_address    <= "00000000";
				coded_address   <= "00000000";
				
				does_belong     <='0';
				wz_num          <= "000";
				wz_off          <= "0000";	
				
				current_state   <= idle;	
			
			elsif (rising_edge(i_clk)) then
				--scorro i miei output al valore successivo
				o_done    <= o_done_next;
				o_en      <= o_en_next;
				o_we      <= o_we_next;
				o_data    <= o_data_next;
				o_address <= o_address_next;--not sure
				--setto i segnali al valore successivo 
				current_wz      <= next_wz;
				address_request <= address_request_next;
				read_address    <= read_address_next;
				coded_address   <= coded_address_next;
			
				does_belong     <= does_belong_next;
				wz_num          <= wz_num_next;
				wz_off          <= wz_off_next;
				
				current_state <= next_state;
				
			end if;
		end process;
		--potrebbe essere necessario cambiare la sensitivity list
		lambda : process ( current_state, i_start, i_data,current_wz,address_request,read_address,coded_address,
						   does_belong, wz_num , wz_off ) 
		begin 
			--inizializzo i valori dei registri next per l'output
			o_done_next    <= '0';
			o_en_next      <= '0';
			o_we_next      <= '0';
			o_data_next    <= "00000000";
			o_address_next <= "0000000000000000";
			--inizializzo i valori dei segnali successivi 
			next_wz              <= current_wz; 
			address_request_next <= address_request;
			coded_address_next   <= coded_address_next;
			
			--number_wz_next       <= number_wz; 
			does_belong_next     <= does_belong;			
			wz_num_next          <= wz_num;
			wz_off_next          <= wz_off;
			
			next_state           <= current_state;
			
			case current_state is
				--stato di attesa per il segnale di start
				when idle =>
					if i_start = '1' then 
						next_state <= fetch_address;
					else 
						next_state <= idle;
					end if;
				
				--stato in cui richiedo alla RAM l'address da codificare presente in RAM[8] 
				when fetch_address => 
					o_en_next <= '1';
					o_we_next <= '0';
					
					o_address_next <= ram_in_address;
					next_state     <= get_address; 
				--stato in cui ottengo l'address da codificare da RAM[8] e lo salvo in memoria
				when get_address =>
					read_address_next <= i_data;
					next_state <= wz_loop; 
				--stato in cui verifico se ho controllato tutte le working zone, continuo fino a quando non le ho viste tutte o l'address appartiene ad una
				when wz_loop => 
					--N.B La condizione di arresto potrebbe essere su number_wz 8 poichè le WZ vanno da 0 a 7
				
					--Il ciclo continua fino a quando non ho letto tutte le working zone o se l'address appartiene ad una working zone
					if (not (unsigned(wz_num) <= 7) or not (does_belong ='1')) then
						--mi prendo il valore RAM[number_wz] 
						o_en_next      <= '1';
						o_we_next      <= '0';
						--prima volta che uso address_request, ricordati che è inizializzato a 0
						o_address_next <= std_logic_vector( unsigned(address_request)+unsigned(wz_num));
						--passo allo slot successivo 
						--vado ad effettuare la verifica dell'address con la wz che ho preso 
						next_state     <= get_wz;
					elsif ( unsigned(wz_num) = 8) then--questo if dovrebbe essere inutile
				        --se sono arrivato all'ultima working zone invece passo al controllo
						next_state     <= calc_address;
					end if;
				--carico l'address base della working zone 	
				when get_wz =>
					next_wz    <= i_data; 
					next_state <= check_wz;
				--controllo se l'address appartiene o meno ad una working zone e capisco se devo continuare a scorrere o se passare alla costruzione dell'address finale	
				when check_wz => 
				--domanda ma perchè qua metto i_data?
				--RISPOSTA: errore, a me interessa sapere se l'address richiesto da RAM[8] si trova nell'intorno della [current_wz, current_wz+4], 
				--          quindi il confronto da fare è tra read_address che contiene RAM[8] e la current_wz che contiene l'address base della working zone corrente
					--if ( unsigned(i_data)>= unsigned(current_wz) and unsigned(i_data)<=(unsigned( current_wz) + 4))then
					if ( unsigned(read_address)>= unsigned(current_wz) and unsigned(read_address)<=(unsigned(current_wz)+4))then --modifica proposta
						does_belong_next <= '1';
						next_state       <= calc_address; 
					elsif ( unsigned(wz_num) = 7 ) then 
						--ho controllato tutte le working zones, vado allora a calcolare l'address
						next_state   <= calc_address;
					
					else 
						--decido di passare al successivo solo se non sono arrivato alla fine 
						wz_num_next      <= std_logic_vector( unsigned(wz_num) +1);
						next_state       <= check_wz;
					end if;
				-- stato in cui calcolo l'address in base alla sua appartenenza o meno ad una working zone	
				when calc_address =>
				    --codifica one-hot per address 
					if ( does_belong = '1' ) then 
						--calcolo il numero della wz e il suo offset
						wz_off_next      <= (others => '0');
						wz_off_next(to_integer(unsigned(read_address) - unsigned(current_wz))) <= '1';
					--  coded_address_next <= does_belong & wz_num & wz_off_next; --alternativa proposta	
						coded_address_next <= does_belong_next & wz_num_next & wz_off_next;
					
					elsif ( does_belong = '0') then
					-- da rivedere riguardo il read addres(6 downto 0)
						coded_address_next(7)             <= does_belong;
						coded_address_next ( 6 downto 0 ) <= read_address ( 6 downto 0 );
					
					end if;
					next_state <= output_address;
				--stato in cui scrivo in memoria il valore finale dell'address in memoria
				when output_address => 
					o_en_next      <= '1';
					o_we_next      <= '1';
					o_address_next <="0000000000001001";
					o_data_next <= coded_address;
					o_done_next <='1';
					
					next_state <= done;
				--stato di completamento in cui attendo un nuovo segnale di start
				when done => 
					if ( i_start = '0') then 
						address_request_next <= "0000000000000000";
						read_address_next    <= "00000000";
						coded_address_next   <= "00000000";
						next_wz              <= "00000000";
						wz_num_next          <= "000";
						wz_off_next          <= "0000";
						o_done_next          <= '0';					
						
						next_state <= idle;
					end if;
			end case; 
		end process; 
end behavioral;