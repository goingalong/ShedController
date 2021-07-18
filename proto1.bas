#rem
Switches controller for Blue Shed

#endrem

'#define simulate 'set to compile in debug lines for simulation

#picaxe20x2
#no_data
#no_table

symbol frequency = m8 'to enable 9600 baud default
setfreq frequency
symbol timer_tic =34286 '1 sec ticks at 8MHz 
settimer  timer_tic
'constants
symbol comm_speed = T9600_8
symbol door_move_time = 30 'secs
symbol light_flash_time =  1 'secs on/off time to indicate door closing
symbol heartbeat_flash_time = 1'sec to indicate program is looping
symbol true = 1
symbol false = 0
symbol down = 0
symbol up = 1

'devices
symbol light_chan 		=  b.0
symbol dr_up_chan		=  b.1
symbol dr_down_channel 		=  b.2
symbol fairy_light_channel 	=  b.3
symbol rfid_chan 		=  b.6 'hserin
symbol heartbeat_led 		=  b.7
symbol hserout_channel 		=  c.0
symbol dr_sw_remote_down 	=  c.1
symbol dr_sw_remote_up 		=  c.2
symbol light_sw_remote 		=  c.3
symbol fairy_sw_remote 		=  c.4
symbol dr_sw_local 		=  c.6
symbol light_sw_local 		=  c.7

'status bits
symbol dr_state = 			bit0
symbol dr_direction = 			bit1
symbol light_flashing = 		bit2
symbol light_state =			bit3
symbol fairy_lights_state = 		bit4
symbol loc_dr_sw_prior_status =	bit5
symbol rem_dr_sw_up_prior_status =	bit6
symbol loc_lt_sw_prior_status =	bit7
symbol rem_lt_sw_prior_status =	bit8
symbol rem_dr_sw_down_prior_status =bit9
symbol rem_fairy_sw_prior_status =  bit10

 
'Memory usage
symbol status = w0 'container for status bits
symbol temp = w1
'symbol tempb0 = b2
'symbol tempb1 = b3
symbol light_flash_end_time = w2
symbol dr_move_end_time = w3
symbol heartbeat_event = w4 'to hold the next toggle time for the indicator led

#rem
PROGRAM BEGINS HERE
#endrem

w0 = 0 'clear down all status bits

#ifndef simulate 'following only if in simulate mode
hsersetup B9600_8,%00001 'background receive from RFID reader
#endif

pause 2000 ' to let timer run past 0 at start

do 'main loop

#rem
Housekeeping Tasks
#endrem

#ifdef simulate
	if status <> temp then
		temp = status
		'sertxd (dr_stopped,dr_moving,dr_upwards,dr_downwards,10,13)
		endif
	#endif

if heartbeat_event <= timer then
	'use this event to prevent timer overflow by resetting (it not in use)
	if timer > light_flash_end_time AND timer > dr_move_end_time then
		settimer  timer_tic 'reset the timer
		endif	
	toggle heartbeat_led
	heartbeat_event = timer + heartbeat_flash_time
	endif

#rem
Check through all switch inputs and set appropriate status's
#endrem

'Check for RFID input. Actual input content is ignored!
if hserptr > 0 then 'at least one character has come in - so open door
	gosub set_open_door
endif 'hserptr will be reset when the door stops



'Read the door local button. Stops the door if moving. Brings it down if already stopped.
 if  pinc.6 = on AND  loc_dr_sw_prior_status = off then
 	'switch has just been pressed - meaning stop or go down
 	loc_dr_sw_prior_status = true 'block further switch actions !!
 	gosub set_shut_door
 elseif pinc.6 = off then
 	loc_dr_sw_prior_status = false
endif
 		
 'Read the door remote down button.
 if  pinc.1 = on AND  rem_dr_sw_down_prior_status = off then
 	'button has just been pressed - meaning stop or go down
 	rem_dr_sw_down_prior_status  = true 'block further button actions !!
 	gosub set_shut_door
 elseif  pinc.1 = off then 
 	rem_dr_sw_down_prior_status  =  false
endif

'Read the door remote up button. 
 if  pinc.2 = on AND  rem_dr_sw_up_prior_status = off then
 	'switch has just been pressed - meaning go up
 	rem_dr_sw_up_prior_status = true 'block further button actions !!
 	gosub set_open_door
 elseif pinc.2=off then
 	rem_dr_sw_up_prior_status =  false	
endif
		

'read the local light button and toggle light setting
if pinc.7 = on AND loc_lt_sw_prior_status = off then
	loc_lt_sw_prior_status = true
	gosub toggle_light
elseif pinc.7=off then
	 loc_lt_sw_prior_status = false
endif

'read the remote light button and toggle light setting
if pinc.3 = on AND rem_lt_sw_prior_status = off then
	rem_lt_sw_prior_status = true
	gosub toggle_light
elseif pinc.3 = off then
	 rem_lt_sw_prior_status = false
endif

'read the remote fairy lights button
if pinc.4 = on AND rem_fairy_sw_prior_status = off then
	rem_fairy_sw_prior_status = true
  	gosub toggle_fairies 
elseif pinc.4 = false then
	rem_fairy_sw_prior_status = false
endif
 

#rem
Check through all status bits/timers and set output relays.
********************************************************
#endrem

'check door moving timer and enable motor
if  dr_move_end_time  > timer then
	'not timed out

	if  dr_direction= up then
		high b.1 'go up
		low b.2 'not down
		high b.0 ' turn light on
	else
		high b.2 'go down
		low b.1 'not up
		gosub flash_light
	endif
else
	gosub set_stop_door
	hserptr = 0
endif

'set light to its demanded state if door is not moving
if dr_move_end_time <= timer then	
	if light_state = on then 
		high b.0
	else
		low b.0
	endif
endif

'set fairy lights relay to demand state
if fairy_lights_state = on then
	high b.3
else 
	low b.3
endif

loop
end	

#rem
subroutines ***************************************************************
#endrem


set_stop_door:
'stop motors and stop timeout
	low  b.2  'dr_down_chan
	low b.1   'dr_up_chan
	dr_move_end_time = timer -1 'stop movement timer
	light_flashing = false
	return

set_shut_door:
'shut or stop the door (if already moving)
 	if  dr_move_end_time > timer then 'door is moving so set status to stop it now
 		gosub set_stop_door 'disconnect power
 		
 	else  'door is already stopped so set status move it down
 		dr_direction = down
 		dr_move_end_time = timer +  door_move_time
 		light_flashing  = true  	 
 	endif 
return

set_open_door:
 	if  dr_move_end_time > timer  AND  dr_direction = down then 'door is moving in the wrong direction
 	 	gosub set_stop_door 		
 	elseif dr_move_end_time <= timer then ' door is already stopped
		dr_direction = up
		dr_move_end_time = timer +  door_move_time
	endif 'otherwise door must already be moving up
return

toggle_light:
	if  light_state  = false then
		light_state = true
	else
		light_state = false
	endif
return

toggle_fairies:
	if  fairy_lights_state  = false then
		fairy_lights_state = true
	else
		fairy_lights_state = false
	endif
return

flash_light:
' indicate downward door by flashing the exterior light
	if light_state = off then 'flash only when the light is not already on
		if light_flash_end_time <= timer then
			toggle b.0
			light_flash_end_time = timer + light_flash_time
			endif
	endif
return
	
#rem
Notes:

1. To avoid the door motor being driven in both up and down directions simultaneously
	the door control relays are wired so their switch outputs are in series. Ie
	the NC contact of the first relay (up) is connected to the common of the second
	relay. This ensures that both are not in the closed state together, even for a fraction.
	
2. As a back-up the key switch is wired so that it's common input is fed from the NC contact 
	of the down relay. This ensures that the key switch can only be used when the up/down
	relays are not engaged.
	
3. At each heartbeat the timer is reset (if it is not being used to control timing) -
	this is to prevent timer overflow.

#endrem
