; Directives
	PRESERVE8
	THUMB
		
;Equates
;;;
;;;
;;;
INITIAL_MSP 	EQU		0x20001000	;initial main stack pointer
;PORT A GPIO
GPIOA_CRL		EQU		0x40010800	; (0x00) Port Configuration Register 
GPIOA_ODR		EQU		0x4001080C	; (0x0C) Port Output Data Register

;PORT B GPIO - Base Addr: 0x40010C00
GPIOB_CRL    EQU        0x40010C00    ; (0x00) Port Configuration Register 
GPIOB_IDR    EQU        0x40010C08    ; (0x08) Port Input Data Register
GPIOB_ODR    EQU        0x40010C0C    ; (0x0C) Port Output Data Register

;RCC Registers - Base Addr: 0x40021000
RCC_APB2ENR     EQU        0x40021018    ; APB2 Peripheral Clock Enable Register 

; Times for delay routines
DELAYTIME       EQU    600000       
HALF_DELAYTIME  EQU    800000        
SHORT_DELAYTIME EQU    200000        
	
;can be changed to fit players preference
PRELIMWAIT		EQU	   800000        
REACT_TIME		EQU    1000000	
WINNING_TIME	EQU	   7	
LOSING_TIME		EQU    15	

;Random variable constants 
A	EQU		1664525 
C 	EQU		1013904223
	
	
;Number of cycles to go through game
;can be changed to fit players preference
NUM_CYCLES	 EQU		15		
; Vector Table Mapped to Address 0 at Reset, Linker requires __Vectors to be exported

			AREA    RESET, DATA, READONLY
			EXPORT  __Vectors
;The DCD directive allocates one or more words of memory, aligned on four-byte boundaries, 
;and defines the initial runtime contents of the memory.


__Vectors
				DCD	INITIAL_MSP		; stack pointer value when stack is empty
				DCD	Reset_Handler		; reset vector
	 
				ALIGN

;My  program,  Linker requires Reset_Handler and it must be exported

				AREA    MYCODE, CODE, READONLY
				ENTRY
				EXPORT	Reset_Handler



	ALIGN
Reset_Handler PROC
		BL GPIO_START
		BL CONFIG_GPIOA
		BL CONFIG_GPIOB
		BL waitingForPlayer
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; GPIO_START
;;;
;;; Require:
;;;		-address of RCC_APB2ENR
;;;		-need to set bits 2 and 3
;;;
;;;	Promise:
;;;		-will enable clock for ports a and b
;;;
;;;	Notes:
;;;		-RCC = Reset and clock Control
;;;		-Port A is used for the first three LEDS
;;;		-PORT B is used for pushbuttons and last LED
;;;		
;;;		Step 1: Load address of RCC_APB2ENR
;;;		Step 2: get the value of the address
;;;		Step 3: enable bits 2 and 3
;;;		Step 4: store value of set bits into address to enable ports
;;;		Step 5: Branch back to main
;;;
;;;	Modifies:
;;;		-R6 by getting address of RCC_APB2ENR
;;;		-r0 is changed to bits to enable clock
;;;		-RCC_APB3ENR bits are set/masked
;;;
	
	ALIGN	
GPIO_START PROC
	;enable the port a and b 
	ldr r6, = RCC_APB2ENR 
	b stuff1
	LTORG 
stuff1
	ldr r0, [r6]
	orr r0, #0xC ;enable bits 2 and 3
	str r0,[r6]
	BX LR
	endp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;	CONFIG_GPIOA
;;;		
;;;	Require:
;;;		-Address of GPIOA_CRL
;;;		-Need to set bit 0, 1 and 4 (first three LEDs)
;;;
;;;	Promise:
;;;		-will enable a push-pull output
;;;
;;;	Notes:
;;;		Step 1: Load address of GPIOA_CRL
;;;		Step 2: get value of address
;;;		Step 3: set desired bits of 0, 1, 4
;;;		Step 4: mask the desired bits
;;;		Step 5: store value in r0 to enable set bits for lighting first three LEDs
;;;		Step 6: Branch back to main
;;;
;;;	Modifies:
;;;		-r6 by getting address of GPIOA_CRL
;;;		-r0 is changed to mode bits for port A and then contians set/masked bits
;;;		-r9 contains the bits that needs to be on active high (0,1,4)
;;;			as well as the mask of the bits
;;;		-GPIOA_CRL bits are set/masked
;;;
CONFIG_GPIOA PROC
	ldr r6, = GPIOA_CRL 
	b stuff2
	LTORG
stuff2
	ldr r0, [r6]
	MOVW r9, #(0x30033 & 0xffff)
	MOVT r9, #(0x30033>>16)
	orr r0, r9
	MOVW r9, #(0xFFF3FF33 & 0xffff)
	MOVT r9, #(0xFFF3FF33>>16)
	and r0, r9
	str r0,[r6]
	bx lr
	endp
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;	CONFIG_GPIOB
;;;		
;;;	Require:
;;;		-Address of GPIOB_CRL
;;;		-Need to set bit 0 (Last LED)
;;;
;;;	Promise:
;;;		-will enable a push-pull output
;;;
;;;	Notes:
;;;		Step 1: Load address of GPIOB_CRL
;;;		Step 2: get value of address
;;;		Step 3: set desired bit of 0
;;;		Step 4: mask the desired bit
;;;		Step 5: store value in r0 to enable set bit for lighting Last LED
;;;		Step 6: Branch back to main
;;;
;;;	Modifies:
;;;		-r6 by getting address of GPIOB_CRL
;;;		-r0 contains set/masked bit
;;;		-GPIOB_CRL bits are set/masked
;;;
CONFIG_GPIOB PROC
	ldr r6, = GPIOB_CRL 
	B stuff3
	LTORG
stuff3
	ldr r0, [r6]
	orr r0, #0x3
	and r0, #0xFFFFFFF3
	str r0,[r6]
	bx lr
	endp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;	waitingForPlayer
;;;	
;;;	Require:
;;;		-need output address of GPIOA_ODR and GPIOB_ODR
;;;		-need input address of GPIOB_IDR (pushbuttons)
;;;		-need some delay time to keep LEDs on/off
;;;
;;;	Promise:
;;;		-Flashs all four LEDS on and off in a cycle indefinitely until
;;;			until player touches at least one pushbutton
;;;		-Once a button is pressed program will move into the next phase
;;;			(prelimWait/startGame)
;;;
;;;	Notes:
;;;		-Bit masks will be used to turnoff each LED
;;;
;;;		Step 1: Load address and variables for:
;;;				i)   GPIOA_ODR (first three LEDS), GPIOB_ODR (Last LED)
;;;				ii)  SHORT_DELAYTIME for flashing
;;;				iii) GPIOB_IDR for 4 pushbuttons input
;;;		Step 2: Turn on LED
;;;				2a) loads value of output address (GPIOx_ODR, A or B) to r6
;;;				2b) set desired bit within the port being used
;;;				2c) store value of set bit to Port address
;;;		Step 3: Enter Delay, within Delay if any button is pushed Direct
;;;					to prelimwait/startGame
;;;				3a) load value of GPIOB_IDR address into r8
;;;				3b) check whether specified bit with respect to its assigned button, registers 0
;;;						(whether the button was clicked or not)
;;;				3c) if button registers 0 branch to prelimWait/StartGame
;;;						else keep going through the delay loop
;;;				3d) decrement (delay timer) loop
;;;						-3a,b,c must be inside the decrement loop
;;;						-if NOT 0 keep lopping through the specific decrement label of the LED
;;;						-if 0 move to the next LED and repeat Steps 2, 3, 4 respectively
;;;		Step 4: Turn off LED
;;;				4a) load value of output address (GPIOx_ODR, A or B) to r6
;;;				4b) bit mask which ever bit was set
;;;				4c) store value of masked bit to Port address
;;;
;;;	Modifies:
;;;		R0: Loads address of GPIOA_ODR, this register DOES NOT change again in this routine
;;;		R7: loads value of delay time, this value decrements
;;;		R2: Loads address of GPIOB_ODR, this register DOES NOT change again in this routine
;;;		R3: Loads address of GPIOB_IDR, this register DOES NOT change again in this routine
;;;		R6: Loads value of GPIOx_ODR, A or B, which is then masked to get an individual bit for each LED
;;;		R8: Loads value of GPIOB_IDR, used to check if button was push
;;;		R9: Counter value which will be used later in the random number generator
;;;		GPIOx_ODR, A and B: the value at this memory will be updated by R6 to turn on/off LEDs
;;;
	ALIGN
waitingForPlayer PROC
	mov r9, #0 ;counter for random number generator
startLEDs
	ldr r0, = GPIOA_ODR
	b stuff4
	LTORG
stuff4
	ldr r1, = SHORT_DELAYTIME ;; sorry this line is redundant
	b stuff5
	LTORG
stuff5
	ldr r2, = GPIOB_ODR
	b stuff6
	LTORG
stuff6
	ldr r3, =GPIOB_IDR
	b stuff7
	LTORG
stuff7
	;turn on 1st LED
	ldr r6, [r0] ;takes the value of r0 and stores it in r6
	orr r6, #0x1 ;changes bit 0 to an active high
	str r6, [r0] ;stores r6's value to address of r0 
	ldr r7, = SHORT_DELAYTIME ; this is where the delay time is actually stored
	b stuff8
	LTORG ;this was needed (recommended by the compiler) to keep the program running
stuff8
	; decrements delay time until 0
decrement_loop
	add r9, r9, #1
	ldr r8, [r3]
	and r8, #0x10
	cmp r8, #0
	BEQ helper
	ldr r8, [r3]
	and r8, #0x40
	cmp r8, #0
	BEQ helper
	ldr r8, [r3]
	and r8, #0x100
	cmp r8, #0
	BEQ helper
	ldr r8, [r3]
	and r8, #0x200
	cmp r8, #0
	BEQ helper
	sub r7, r7, #1 
	cmp r7, #0
	BNE decrement_loop
	
	;turns 1st LED off
	ldr r6, [r0]
	and r6, #0xFFFFFFFE
	str r6, [r0]
	
	;second light turning on and off
	ldr r6, [r0]
	orr r6, #0x2
	str r6, [r0]
	ldr r7, =SHORT_DELAYTIME
	b decrement_loop2
	LTORG
decrement_loop2
	add r9, r9, #1
	ldr r8, [r3]
	and r8, #0x10
	cmp r8, #0
	BEQ startGame
	ldr r8, [r3]
	and r8, #0x40
	cmp r8, #0
	BEQ startGame
	ldr r8, [r3]
	and r8, #0x100
	cmp r8, #0
	BEQ startGame
	ldr r8, [r3]
	and r8, #0x200
	cmp r8, #0
	BEQ startGame
	sub r7, r7, #1
	cmp r7, #0
	BNE decrement_loop2
	ldr r6, [r0]
	and r6, #0xFFFFFFFD ; turn off LED
	str r6, [r0]

	;third light turning on and off
	ldr r6, [r0]
	orr r6, #0x10
	str r6, [r0]
	ldr r7, =SHORT_DELAYTIME
	b decrement_loop3
	LTORG
decrement_loop3
	add r9, r9, #1
	ldr r8, [r3]
	and r8, #0x10
	cmp r8, #0
	BEQ startGame
	ldr r8, [r3]
	and r8, #0x40
	cmp r8, #0
	BEQ startGame
	ldr r8, [r3]
	and r8, #0x100
	cmp r8, #0
	BEQ startGame
	ldr r8, [r3]
	and r8, #0x200
	cmp r8, #0
	BEQ startGame
	sub r7, r7, #1
	cmp r7, #0
	BNE decrement_loop3
	ldr r6, [r0]
	and r6, #0xFFFFFFEF
	str r6, [r0]
	B continue
; this brings the branching of startGame closer cause without this branching to startGame is unattainable
helper
	B startGame
continue
	;fourth light turning on and off
	ldr r6, [r2]
	orr r6, #0x1
	str r6, [r2]
	ldr r7, =SHORT_DELAYTIME
	b decrement_loop4
	LTORG
decrement_loop4
	add r9, r9, #1
	ldr r8, [r3]
	and r8, #0x40
	cmp r8, #0
	BEQ startGame
	ldr r8, [r3]
	and r8, #0x100
	cmp r8, #0
	BEQ startGame
	ldr r8, [r3]
	and r8, #0x200
	cmp r8, #0
	BEQ startGame
	sub r7, r7, #1
	cmp r7, #0
	BNE decrement_loop4
	ldr r6, [r2]
	and r6, #0xFFFFFFFE
	str r6, [r2]
	B startLEDs ; go back to cylce through the LEDs until a button is pushed
	endp
		
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;	startGame
;;;
;;;	Require:
;;;		-Delay times
;;;			-Number of cycles the player can play
;;;			-initial seed value (r9 from the waiting for player)
;;;			-reaction time (needs to be lesser as player moves thorugh the game)
;;;			-Random value address (0x20001000)
;;;			-address to store array of possible correct or incorrect LEDs bits (0x20002000)
;;;	Promise:
;;;		-will initiate a preliminary wait so the player can get ready to start the game.
;;;		- startGame will randomize which LED to light up and will give the player a short
;;;			time (react time) to press the corresponding button
;;;		-if the player presses an incorrect button or it the react time runs out
;;;			then it will branch to endFailure subroutine
;;;		-if the player correctly presses the right button with the correspondig LED
;;;			the react time will get faster. This will continue until the player presses
;;;			the correct button 15 times which will then branch to endSuccess subroutine
;;;
;;;	Notes:
;;;		-to make this process simple i decided to creater an array of the 4 LEDs
;;;			because each LED is a subroutine, and within Each LED it checks if the corresponding button
;;;			was pressed in accordance to the right LED
;;;		-Random number generator can ignore overflow
;;;			- should be Xn+1 = A*(Xn)+C, Xn is the seed value, R9
;;;		Step 1: ensure all LEDs are off
;;;			1a) load r10 with address of GPIOx_ODR, A and B
;;;			1b) load r11 with the valueof the GPIO address
;;;			1c) bit mask each bit for the corresponding LEDs to turn them off
;;;			1d) store the masked value of r11 in the r10 address
;;;		Step 2: store value of r9 into memory address stored in r4
;;;			2a) store another memory address in r3 for the array of LEDs
;;;		Step 3: Create array of 4 LEDs in memory address 0x20002000
;;;			3a) load the value of the four LEDS respectively into R5
;;;			3b) store the value from R5 to R3 memory address
;;;			3c) add 4 bits to create space for the next value of the next LED. repeat 3a,b,c for each LED
;;;		Step 4: load r11, and r12 with num cycles value and react time value respectively
;;;		Step 5: initialize prelimWait (all LEDs are turn of for a short time to get player ready)
;;;			5a) load r1 with PRELIMWAIT value
;;;			5b)	check if numcycles is done if so branch to endSuccess (numcycle decrements when implementing each
;;;				LED to be stored in an array
;;;			5c) if not move through prelimwait value and decrement till 0
;;;		Step 6: generate random number
;;;			6a) load r2, and r3 with the A and C constants respectively
;;;			6b) load memory address of r4 ro r9 (r9 is the seed value)
;;;			6c) follow formular of A*(Xn)+ C to generate random number
;;;			6d) multiply A and r9 then store the value back in r9
;;;			6e) add r9 and C then store value into r9
;;;			6f) store value in r9 back to the memory address in r4
;;;			6g) left shift r9 30 bits
;;;			6h) set bit in r9 
;;;			6i) left shift r9 2 bits
;;;			6j) add the value of r9 to the array memory address
;;;			6k) load r9 address to r8
;;;			6l) branch to r8 to retain the random number within the memory address
;;;
;;; Modifies:
;;;		R10: loads address of GPIOA_ODR, doesnt change in this routine
;;;		R11: loads value of r10 and also value of num cycles
;;;		R4:  memory address for random number
;;;		R9: contains random number (seed value)
;;;		R3: meemory address to store LED array
;;;		R5: loads possible outcome values of each LED 
;;;		R12: loads value of reaction time (this will decrement when implementing possible outcome values for each LED)
;;;		R1: laods value of prelimwait (decrements giving players a short time span to prepare to play)
;;;
	
	ALIGN
startGame PROC
	;this is to turn of all the LEDS
	ldr r10, = GPIOA_ODR
	ldr r11, [r10]
	and r11, #0xFFFFFFEC ;set bit 0, 1, 4 to active low
	str r11,[r10]
	
	ldr r10, = GPIOB_ODR
	ldr r11, [r10]
	and r11, #0xFFFFFFFE
	str r11,[r10]
	
	movw r4, #(0x20001000 & 0xffff)
	movt r4, #(0x20001000 >>16)
	str r9, [r4]
	movw r3, #(0x20002000 & 0xffff)
	movt r3, #(0x20002000 >>16)
	;creating an array of the 4 LEDS
	ldr r5, = first_LED
	b stuff9
	LTORG
stuff9
	str r5, [r3]	
	add r3, r3, #4 ; moves to the next set of four bits to store the address of the following subroutine
	ldr r5, = second_LED
	b stuff10
	LTORG
stuff10
	str r5, [r3]
	add r3, r3, #4
	ldr r5, = third_LED
	b stuff11
	LTORG
stuff11
	str r5, [r3]
	add r3, r3, #4
	ldr r5, = fourth_LED
	b stuff12
	LTORG
stuff12
	str r5, [r3]
	ldr r11, = NUM_CYCLES
	ldr r12, = REACT_TIME
; waiting time before beginning

prelimWait
	ldr r1, = PRELIMWAIT
	b stuff13
	LTORG
stuff13
	cmp r11,#0
	BEQ endSuccess
prelimWaitLoop
	sub r1, r1, #1
	cmp r1, #0
	BNE prelimWaitLoop
start
	ldr r2, = A
	b stuff14
	LTORG
stuff14
	ldr r3, = C
	b stuff15
	LTORG
stuff15
	ldr r9, [r4] ; loads value of r4 to r9
	mul r9,r2,r9
	add r9, r9, r3
	str r9,[r4] ;store value in r9 back to memory
	lsr r9,r9, #30
	and r9, r9, #3
	lsl r9, r9, #2 ;
	add r9, r9, #0x20002000 
	ldr r8, [r9]
	BX r8
	endp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; endSuccess
;;;
;;; Require:
;;;		-delay time for dispaly LED sequence
;;;		-A and B output ports to display specified LEDs
;;;		
;;;	Promise:
;;;		-when a player wins the game, LEDs will flash in a pattern
;;;			showing that the player won
;;;		-winning pattern will display 7 times indicating a win/level 15
;;;			15 passed
;;;		-Player cannot leave this stage and must wait until sequence is 
;;;			over
;;;
;;;	Notes:
;;;		-Sequence is LED 1,3,2,4
;;;		-steps 3 and 4 are within the loop in step 2
;;;		Step 1: load r0, r1 with address if GPIOx_ODR, A and B.
;;;				1a) load value of winning time (how long the sequence will show for) in  r2
;;;		Step 2: initialize loop to display sequence
;;;				2a) load value of r0 in r6
;;;				2b) set bit for LED
;;;				2c) store set bit back in r0
;;;				2d) load value of half delaytime in r3
;;;		Step 3: decrement half delaytime
;;;		Step 4: bit mask to turn off LED
;;;				4a) load value of r0 (currently bit set is to turn on LED) to r6
;;;				4b) bit mask to turn off LED
;;;				4c) store the masked bit back in r0
;;;		Step 5: repeat step 3,4 for each LED respectively in r2 (follow sequence to display pattern)
;;;		Step 6: branch to waitingFor Player
;;;
;;; Modifies:
;;;		R0: contains address of GPIOA_ODR
;;;		R1: contains address of GPIOB_ODR
;;;		R2: contains value of winning time
;;;		R6: loads value of R0 or R2, depending on LED to turn on, 
;;;				plus contains masked bits to turn of LEDs
;;;		R3: contains vlaue of half delaytime
;;;		GPIOx_ODR, A and B: changes bits on LEDs turning on and off
;;;

	ALIGN
endSuccess PROC
	ldr r0, = GPIOA_ODR
	ldr r1, = GPIOB_ODR
	ldr r2, = WINNING_TIME

loop
	ldr r6, [r0]
	orr r6,	#0x1
	str r6, [r0]
	ldr r3, = HALF_DELAYTIME
decrementes
	sub r3, r3, #1
	cmp r3, #0
	BNE decrementes
	ldr r6, [r0]
	and r6, #0xFFFFFFFE
	str r6, [r0]
	
	ldr r6, [r0]
	orr r6,	#0x10
	str r6, [r0]
	ldr r3, = HALF_DELAYTIME
decrementes2
	sub r3, r3, #1
	cmp r3, #0
	BNE decrementes2
	ldr r6, [r0]
	and r6, #0xFFFFFFEF
	str r6, [r0]
	
	ldr r6, [r0]
	orr r6,	#0x2
	str r6, [r0]
	ldr r3, = HALF_DELAYTIME
decrementes3
	sub r3, r3, #1
	cmp r3, #0
	BNE decrementes3
	ldr r6, [r0]
	and r6, #0xFFFFFFFD
	str r6, [r0]
	
	ldr r6, [r1]
	orr r6,	#0x1
	str r6, [r1]
	ldr r3, = HALF_DELAYTIME
decrewomentes
	sub r3, r3, #1
	cmp r3, #0
	BNE decrewomentes
	ldr r6, [r1]
	and r6, #0xFFFFFFFE
	str r6, [r1]
	
	sub r2, r2, #1
	cmp r2, #0
	BNE loop
	B waitingForPlayer
	bx lr
	endp
		
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;	this isnt neccessarily a subroutine, they appear so
;;; because i didnt know how else to determine how each LED will
;;; turn on at random. so each LED was implemented seperately
;;; determing the outcome, if one of them comes on at random
;;; which checks to see if the right button was pressed. the 
;;; random value was retrieve from the memory address 0x20001000 when the random
;;; numbers where stored in r9 which was then transferred to the memory address
;;;
;;; this comment is for each LED
;;;
;;;	Require:
;;;		-GPIOx_ODR, A and B outputs ports
;;;		-react time r12
;;;		-array to store each LED (r8)
;;;		-success and failure label which determines if the 
;;;			corresponding button to each LED was pressed
;;;		-delay time 
;;;
;;; Promise:
;;;		-the random number retrieve will display any one of the 4 LEDs
;;;		-if player hits the correct button react time gets faster
;;;		-if not game over, gets branched to endFailure subroutine
;;;	
;;;	Notes:
;;;		Step 1: load address of GPIOA_ODR to r0, except for the last LED where r0 is loaded with GPIOB_ODR
;;;				and GPIOB_IDR to r1 respectively
;;;		Step 2: load the value of r0 to r6
;;;		Step 3:set bit for corresponding LED
;;;		Step 4: store the set bit to r0
;;;		Step 5: mov the react time to a dummy register r10, so it can be reduced correctly for each LED
;;;				optimizing the random LED of turning on
;;;		Step 6: loop through each button to see if the right one was pressed according to its 
;;;				designated LED. 
;;;				6a) load address of input register GPIOB_IDR
;;;				6b) check to see which of the 4 buttons was click
;;;				6c) if right button was clicked branch to success label
;;;					if not branch to failure label
;;;		Step 7: either success or failure turn off LED
;;;				7a) load value of bit in r0 to r6 (turned on LED)
;;;				7b) mask the bit to turn off LED
;;;				7c) store new bit value back to r0
;;;				7d) decrement reaction time and number of cycles
;;;				7e) if success reduce delay time between each LED coming on and off
;;;				7f) if failure branch to endFailure
;;;
;;; Modifies:
;;;		R0: Either contains address GPIOA_ODR or GPIOB_ODR which has bits stored for on/off LEDs
;;;		R1: contains GPIOB_IDR address (pushbbuttons)
;;;		R6: contains bit changes of on/off LED
;;;		R10: dummy register to decrement reaction time for Each LED implementation
;;;		R8: still contains the memory address where random numbers are stored
;;;		R12: original react time (decrements after each button is pressed according to the right light successfully)
;;;		R11: Num cycles decrements as each LED comes on at random
;;;		R7: contains value to subtract from r12 each time its success
;;;
	ALIGN
first_LED PROC
	ldr r0, = GPIOA_ODR
	ldr r1, = GPIOB_IDR
	ldr r6, [r0]
	orr r6,	#0x1 ;set bit 0, this is for first LED
	str r6, [r0]
	mov r10, r12
decrementReactTime
	ldr r8, [r1]
	and r8, #0x10
	cmp r8, #0
	BEQ success1
	ldr r8, [r1]
	and r8, #0x40
	cmp r8, #0
	BEQ failure1
	ldr r8, [r1]
	and r8, #0x100
	cmp r8, #0
	BEQ failure1
	ldr r8, [r1]
	and r8, #0x200
	cmp r8, #0
	BEQ failure1
	sub r10, r10, #1
	cmp r10, #0
	BNE decrementReactTime
	B failure1
success1
	ldr r6, [r0]
	and r6, #0xFFFFFFFE
	str r6, [r0]
	sub r11, r11, #1
	mov r7, #50000
	sub r12, r12, r7
	B prelimWait
failure1
	ldr r6, [r0]
	and r6, #0xFFFFFFFE
	str r6, [r0]
	B endFailure
	endp
	ALIGN
second_LED PROC
	ldr r0, = GPIOA_ODR
	ldr r1, = GPIOB_IDR
	ldr r6, [r0]
	orr r6,	#0x2
	str r6, [r0]
	mov r10, r12
decrementReactTime2
	ldr r8, [r1]
	and r8, #0x10
	cmp r8, #0
	BEQ failure2
	ldr r8, [r1]
	and r8, #0x40
	cmp r8, #0
	BEQ success2
	ldr r8, [r1]
	and r8, #0x100
	cmp r8, #0
	BEQ failure2
	ldr r8, [r1]
	and r8, #0x200
	cmp r8, #0
	BEQ failure2
	sub r10, r10, #1
	cmp r10, #0
	BNE decrementReactTime2
	B failure2
success2
	ldr r6, [r0]
	and r6, #0xFFFFFFFD
	str r6, [r0]
	sub r11, r11, #1
	mov r7, #50000
	sub r12, r12, r7
	B prelimWait
failure2
	ldr r6, [r0]
	and r6, #0xFFFFFFFD
	str r6, [r0]
	B endFailure
	endp

	ALIGN
third_LED PROC
	ldr r0, = GPIOA_ODR
	ldr r1, = GPIOB_IDR
	ldr r6, [r0]
	orr r6,	#0x10
	str r6, [r0]
	mov r10, r12
decrementReactTime3
	ldr r8, [r1]
	and r8, #0x10
	cmp r8, #0
	BEQ failure3
	ldr r8, [r1]
	and r8, #0x40
	cmp r8, #0
	BEQ failure1
	ldr r8, [r1]
	and r8, #0x100
	cmp r8, #0
	BEQ success3
	ldr r8, [r1]
	and r8, #0x200
	cmp r8, #0
	BEQ failure3
	sub r10, r10, #1
	cmp r10, #0
	BNE decrementReactTime3
	B failure3
success3
	ldr r6, [r0]
	and r6, #0xFFFFFFEF
	str r6, [r0]
	sub r11, r11, #1
	mov r7, #50000
	sub r12, r12, r7
	B prelimWait
failure3
	ldr r6, [r0]
	and r6, #0xFFFFFFEF
	str r6, [r0]
	B endFailure
	endp

	ALIGN
fourth_LED PROC
	ldr r0, = GPIOB_ODR
	ldr r1, = GPIOB_IDR
	ldr r6, [r0]
	orr r6,	#0x1
	str r6, [r0]
	mov r10, r12
decrementReactTime4
	ldr r8, [r1]
	and r8, #0x10
	cmp r8, #0
	BEQ failure4
	ldr r8, [r1]
	and r8, #0x40
	cmp r8, #0
	BEQ failure4
	ldr r8, [r1]
	and r8, #0x100
	cmp r8, #0
	BEQ failure4
	ldr r8, [r1]
	and r8, #0x200
	cmp r8, #0
	BEQ success4
	sub r10, r10, #1
	cmp r10, #0
	BNE decrementReactTime4
	B failure4
success4
	ldr r6, [r0]
	and r6, #0xFFFFFFFE
	str r6, [r0]
	sub r11, r11, #1
	mov r7, #50000
	sub r12, r12, r7
	B prelimWait
failure4
	ldr r6, [r0]
	and r6, #0xFFFFFFFE
	str r6, [r0]
	B endFailure
	endp
		
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; endFailure
;;;
;;;	Require: 
;;;		-GPIOx_ODR, A and B
;;;		-delaytimes (includes losing time for losing pattern)
;;;		-num cycles
;;;	
;;;	Promise:
;;;		-will indicate the player's score in binary
;;;			and then branch back to waitingForPlayer
;;;
;;;	Notes:
;;;		Step 1: load address/values of each registers/constants
;;;		Step 2: when player pushes incorrect button or run out of time
;;;				check/compare their score (how many did they get correctly) with 
;;;				the corresponding decimal
;;;		Step 3: corresponding decimal
;;;				3a) load r3 and/or r5 with the value of the repective ouput port address (GPIOx_ODR, A or B)
;;;				3b) set the bits which corresponds to the score the player recieved
;;;					converting binary to hex which will display the score on the LED as binary
;;;					(off is 0 and on is 1)
;;;		Step 4: delay showing LEDs therefore there is an interval, hence flashing the player's score
;;;		Step 5: flash the player's score (in Binary) for a certain amount of time (LOSING_TIME)
;;;				by decrementing LOSING_TIME
;;;		-repeat step 2 to 5 for each score from 1 to 15
;;;
;;; Modifies:
;;;		R7: contains Numcycles DOES NOT CHANGE (just needed to get player's score)
;;;		R9: DelayTime value (decremented throught the loop
;;;		R12: LosingTime value (decrements after getting player's score in binary)
;;;		R11: contains player's score
;;;		R3: address of GPIOA_ODR
;;;		R5: address of GPIOB_ODR
;;;		R6: contains value of bits to be stored and remove from the output ports
;;;		GPIOx_ODR, A and B: changes bits on LEDs turning on and off
	ALIGN
endFailure PROC
	ldr r7, = NUM_CYCLES
	ldr r9, = DELAYTIME
	ldr r12, = LOSING_TIME
	sub r11,r7,r11
	ldr r3, = GPIOA_ODR
	ldr r5, = GPIOB_ODR
outerloop
	cmp r11, #0
	BEQ score0 ; if the player fails to hit the first LED that comes up
	cmp r11, #1
	BEQ score1
	cmp r11, #2
	BEQ score2
	cmp r11, #3
	BEQ score3
	cmp r11, #4
	BEQ score4
	cmp r11, #5
	BEQ score5
	cmp r11, #6
	BEQ score6
	cmp r11, #7
	BEQ score7
	cmp r11, #8
	BEQ score8
	cmp r11, #9
	BEQ score9
	cmp r11, #10
	BEQ score10
	cmp r11, #11
	BEQ score11
	cmp r11, #12
	BEQ score12
	cmp r11, #13
	BEQ score13
	cmp r11, #14
	BEQ score14
	cmp r11, #15
	BEQ score15
	BGT scoreInfinite
score0
	ldr r6, [r3]
	orr r6,	#0x13
	str r6, [r3]
	ldr r6, [r5]
	orr r6,	#0x1
	str r6, [r5]
	B delayloop2 ;wont turn lights off while decrementing the losing time
score1
	ldr r6, [r5]
	orr r6,	#0x1
	str r6, [r5]
	b delayloop
score2
	ldr r6, [r3]
	orr r6,	#0x10
	str r6, [r3]
	b delayloop
score3
	ldr r6, [r3]
	orr r6,	#0x10
	str r6, [r3]
	
	ldr r6, [r5]
	orr r6,	#0x1
	str r6, [r5]
	b delayloop
score4
	ldr r6, [r3]
	orr r6,	#0x2
	str r6, [r3]
	b delayloop
score5
	ldr r6, [r3]
	orr r6,	#0x2
	str r6, [r3]
	ldr r6, [r5]
	orr r6,	#0x1
	str r6, [r5]
	b delayloop
score6
	ldr r6, [r3]
	orr r6,	#0x12
	str r6, [r3]
	b delayloop
score7
	ldr r6, [r3]
	orr r6,	#0x12 ; turn on led 2 and 3 bit 1 and 4
	str r6, [r3]
	ldr r6, [r5]
	orr r6,	#0x1
	str r6, [r5]
	b delayloop
score8
	ldr r6, [r3]
	orr r6,	#0x1
	str r6, [r3]
	b delayloop
score9
	ldr r6, [r3]
	orr r6,	#0x1
	str r6, [r3]
	ldr r6, [r5]
	orr r6,	#0x1
	str r6, [r5]
	b delayloop
score10
	ldr r6, [r3]
	orr r6,	#0x11
	str r6, [r3]
	b delayloop
score11
	ldr r6, [r3]
	orr r6,	#0x11
	str r6, [r3]
	ldr r6, [r5]
	orr r6,	#0x1
	str r6, [r5]
	b delayloop
score12
	ldr r6, [r3]
	orr r6,	#0x3
	str r6, [r3]
	b delayloop
score13
	ldr r6, [r3]
	orr r6,	#0x3
	str r6, [r3]
	ldr r6, [r5]
	orr r6,	#0x1
	str r6, [r5]
	b delayloop
score14
	ldr r6, [r3]
	orr r6,	#0x13
	str r6, [r3]
	b delayloop
score15
	ldr r6, [r3]
	orr r6,	#0x13
	str r6, [r3]
	ldr r6, [r5]
	orr r6,	#0x1
	str r6, [r5]
	b delayloop
;this is just extra code application in case the number of cycle
;increases, if the player corectly finishes the game with the updated
;num cycles the success lights that will show is the waitingForPlayer pattern
scoreInfinite
	b waitingForPlayer
delayloop
	sub r9, r9, #1
	cmp r9, #0
	BNE delayloop
	
	ldr r6, [r3]
	and r6, #0xFFFFFFEC
	str r6, [r3]
	ldr r6, [r5]
	and r6, #0xFFFFFFFE
	str r6, [r5]
	ldr r9, = DELAYTIME
delayloop2
	sub r9, r9, #1
	cmp r9, #0
	BNE delayloop2
	ldr r9, = DELAYTIME
	sub r12,r12,#1
	cmp r12, #0
	BNE outerloop
	ldr r6, [r3]
	and r6, #0xFFFFFFEC
	str r6, [r3]
	ldr r6, [r5]
	and r6, #0xFFFFFFFE
	str r6, [r5]
	B waitingForPlayer
	endp
	END