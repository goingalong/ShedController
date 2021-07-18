#rem
Switches controller for Bike/Tractor Shed
Version Dec 2020
See end_notes

#endrem

'#define simulate 'enable debug lines for simulation

#picaxe 20x2
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
symbol switch_debounce_time = 2 'all switches have the same timeout
symbol true = 1
symbol false = 0
symbol down = 0
symbol up = 1
symbol pressed = 0 'buttons are wired 10k high, so low = pressed.

'devices
symbol dr_up_chan		=  b.0
symbol dr_down_chan 		=  b.1
symbol light_chan 		=  b.2
symbol aux_light_channel 	=  b.3
'spare				=  b.4
symbol dr_warn_input		=  pinb.5 'high says door open AND dark
symbol rfid_chan 			=  b.6 'hserin
symbol heartbeat_led 		=  b.7
symbol hserout_channel 		=  pinc.0 'unused
symbol dr_sw_remote_down 	=  pinc.1
symbol dr_sw_remote_up 		=  pinc.2
symbol light_sw_remote 		=  pinc.3
symbol aux_sw_remote 		=  pinc.4
'spare				=  pinc.5
symbol dr_sw_local 		=  pinc.6
symbol light_sw_local 		=  pinc.7

'status bits
symbol dr_state = 			bit0
symbol dr_direction = 			bit1
'symbol blank = 				bit2
symbol light_state =			bit3
symbol aux_lights_state = 		bit4
 
'Memory usage
symbol status = w0 'container for status bits
symbol old_status = w1
'symbol unused = w2
symbol dr_move_end_time = w3
symbol heartbeat_event = w4 'to hold the next toggle time for the indicator led
symbol switch_debounce_end = w5


#rem
PROGRAM BEGINS HERE
#endrem

w0 = 0 'clear down all status bits

#ifndef simulate 'following only if not in simulate mode
hsersetup B9600_8,%00001 'background receive from RFID reader
#endif

pause 2000 ' to let timer run past 0 at start and allow settling

do 'main loop

#rem
Housekeeping Tasks
************************************************************
#endrem

#ifdef simulate
	if status <> old_status then
		old_status = status
		'sertxd (#status,cr,lf)
		endif
	#endif

if heartbeat_event <= timer then ' timer has expired
	'use this event to prevent timer overflow by resetting (if not in use)
	if timer > dr_move_end_time _
	AND timer >= switch_debounce_end then
		timer=0 'settimer  timer_tic 'reset the timer
		dr_move_end_time = 0
		switch_debounce_end = 0
	endif	
	toggle heartbeat_led
	heartbeat_event = timer + heartbeat_flash_time
	endif

#rem
Check through all switch inputs and set appropriate status's
************************************************************
#endrem
#ifndef simulate
'Check for RFID input. Actual input content is ignored!
if hserptr > 0 then 'at least one character has come in - so open door
	gosub set_open_door
endif 'hserptr is repeatedly reset while the door opens
#endif
	
'Read the door local button. Stops the door if moving. Brings it down if already stopped.
if  dr_sw_local  = pressed AND  timer >= switch_debounce_end then
	switch_debounce_end = timer + switch_debounce_time
 	gosub set_shut_door
endif
		
 'Read the door remote down button.
 if  dr_sw_remote_down = pressed AND  timer >= switch_debounce_end then
	switch_debounce_end = timer + switch_debounce_time
 	'button has just been pressed - meaning stop or go down
 	gosub set_shut_door
endif
 
'Read the door remote up button. 
 if  dr_sw_remote_up = pressed AND  timer >= switch_debounce_end then
	switch_debounce_end = timer + switch_debounce_time
 	'switch has just been pressed - meaning go up
 	gosub set_open_door	
endif
		
'read the local light button and toggle light setting
if light_sw_local  = pressed AND timer >= switch_debounce_end then
	switch_debounce_end = timer + switch_debounce_time
	gosub toggle_light
endif

'read the remote light button and toggle light setting
if light_sw_remote  = pressed AND timer >= switch_debounce_end then
	switch_debounce_end = timer + switch_debounce_time
	gosub toggle_light
endif

'read the remote aux lights button
if aux_sw_remote = pressed AND timer >= switch_debounce_end then
	switch_debounce_end = timer + switch_debounce_time
  	gosub toggle_aux 
endif

#rem
Check through all status bits/timers and set output relays.
********************************************************

To avoid the door motor being driven in both up and down directions simultaneously
	the door control relays are wired so their switch outputs are in series- the 
	NC contact of the first relay is connected to the common of the second
	relay. This ensures that both are not in the power driving state together.

#endrem

'check door moving timer and enable motor
if  dr_move_end_time  > timer then 'not timed out
	
	hserptr = 0 'flush any RFID buffer content

	if  dr_direction= up then
		high dr_up_chan 'go up
		low dr_down_chan  'not down
		high light_chan  ' turn light on
	else
		high dr_down_chan  'go down
		low dr_up_chan 'not up
		high light_chan  ' turn light on
	endif
else
	gosub set_stop_door
endif

'set light to its demanded state if door is not moving and not open at night
if dr_move_end_time <= timer then	
	if light_state = on then 
		high light_chan 
else
	if dr_warn_input = false then
		low light_chan
		endif
	endif
endif

'force the light on if the door open warning signal is present
if dr_warn_input = true then
	high light_chan
	endif

'set aux lights relay to demand state
if aux_lights_state = on then
	high aux_light_channel 
else 
	low aux_light_channel 
endif

loop
end	

#rem
subroutines ***************************************************************
#endrem

set_stop_door:
'stop motors and stop timeout
	low  dr_down_chan
	low dr_up_chan 
	dr_move_end_time = 0 'stop movement timer
	return

set_shut_door:
'shut or stop the door (if already moving)
 	if  dr_move_end_time > timer then 'door is moving so set status to stop it now
 		gosub set_stop_door 'disconnect power
 		
 	else  'door is already stopped so set status & move it down
 		dr_direction = down
 		dr_move_end_time = timer +  door_move_time
		high light_chan  	 
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

toggle_aux:
	if  aux_lights_state  = false then
		aux_lights_state = true
	else
		aux_lights_state = false
	endif
return

	
#rem
Notes:

1.Light now steady on while door is moving. Dec 2020.
2.Takes input from door/shutter warning detector to force the light on if the door is open and it is dark


#endrem
