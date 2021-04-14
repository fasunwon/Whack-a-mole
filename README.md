# Whack-a-mole
Author: Favor Fasunwon
SID: 200384651
Date: December 7th, 2020

This entire program was coded using Cortex-M3 Arm Assembly

1) WHAT THE GAME IS: 
	This LED Whack-a-mole game has 4 LEDs with 4 corresponding pushbuttons. 
	When the game is played, an LED will light up and the player will have to 
	press the corresponding pushbutton, i.e. the LEDs are the moles and the 
	pushbuttons act as the player hitting the moles with a hammer. If the player 
	presses the correct pushbutton while the LED is still on, they gain a point, 
	the LED will turn off, and after a very short interval another LED will 
	turn on. Each time a pushbutton is correctly pressed, the time an LED stays 
	on shortens. This makes the game harder the further the player gets. If the 
	player continues to pick correctly and on time, the game will run up to 15 
	times before showing the player has won. However, if the player does not press 
	the correct pushbutton in time OR presses an incorrect pushbutton, the game 
	will end and the player's score will be shown in binary code.  

2) HOW TO PLAY THE GAME
	a) When all 4 LEDs are flashing, press any of the pushbuttons to begin. 
	b) The 4 LEDs will turn off and will stay off for a few seconds. 
	   After a very short wait, 1 random LED will turn on and the corresponding 
	   pushbutton must be pressed while the LED is on. 
	c) if the player does this correctly, that LED will turn off and another 
	   will turn on. The player then must repeat step b). The further the 
	   player gets, the higher their score and the faster the lights turn 
	   on and off.
	d) if the player does NOT press the correct pushbutton, presses more than
	   one pushbutton, OR the LED turns off before being pressed then the player
	   loses the game. 


	LOSES : if the player loses, the game will end and flash the player's score a few times
		 in binary code. How to recognize your scores is illustrated below in Scoring System.
		 0 is OFF 1 is ON.
	WINS : if the player wins (gets a score of 15) then the game goes into a 
     	      won game sequence of lights and will stay in this sequence a few times 


	SCORING SYSTEM : 
		LED SEQUENCE	SCORE
		
		    	0001	    1
			
		    	0010	    2
			
		    	0011	    3
			
		    	0100	    4
			
		    	0101	    5
			
		    	0110	    6
			
		    	0111	    7
			
			1000	    8
			
			1001	    9	
			    
			1010	   10
			    
			1011	   11
			    
			1100	   12
			    
			1101	   13
			    
			1110	   14
			    
			1111	   15

	*Pressing the reset button will return the player to step a) regardless where
	 they currently are in the game.  

3) implementing the random number for each LED proved difficult to implement in one subroutine so a work around
   was that i made a subroutine for each LED light which incorporates the seed value (random number),thus
   any LED can come on at random. i wish i had more time to implement other fancy features especially getting a unique
   light pattern for scores larger than 15.
	EXTRA FEATURES: if a player gets 0 as a score all the LEDs come on at the same time for a certain amount of time
			then goes back to the waitingForPlayer light sequence

			if a player gets above 15, which can only be when they change the number of cycles, the light sequence
			is exactly the same as waitingForPlayer (i know its weak but i ran out of time to implement something better)



4) In order to customize the game to your preference all what you have to change is the PRELIMWAIT, REACT_TIME, NUM_CYCLES
   WINNING_TIME and LOSING_TIME. they are all located at the top of the program (commented as equates). The values are in decimal 
   so if you want the game faster, reduce the value in REACT_TIME. if you want the Game to be longer, increase the NUM_CYCLES.
   if you dont want to wait for the winning and losing light sequence, all you have to do is decrease the WINNING and LOSING_TIME values.
   *i dont recommend any of these values, excluding NUM_CYCLES, to be below 500000 because it will be impossible to play the game, unless 
    you are the flash :-)
    
    Demo of Whack-a-mole game (https://regina-moodle-prod.kaf.ca.kaltura.com/media/0_4vxcjhpi)
