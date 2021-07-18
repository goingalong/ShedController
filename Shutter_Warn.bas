#rem
Shutter 'open' detector. Uses LTR-559 sensor to detect that the shutter is raised and that it is dark - 
	hence that the shutter has probably been left open at night.
	Outputs a high signal to indicate this state so that the seperate door/light controller
	can turn on the outside light as a warning indication.
#endrem
#picaxe 08m2
#no_data
symbol tmp1 = b0 'w0
symbol tmp2 = b1
symbol  status = b2 'w1
symbol tmp3 = b3
symbol lux1 =  b4 'w2
symbol lux2 = b5
symbol range1 = b6 'w3
symbol range2 = b7

symbol warning =  c.4
pause 100 'allow sensor to start up
sertxd("starting",cr,lf)
output warning 'set pin to output mode
high warning

'enable i2c communication with the LTR-559
hi2csetup i2cmaster,0x46,i2cfast,i2cbyte
'fetch manufacturer data
hi2cin 0x86,(tmp1)
sertxd ("maker ",#tmp1,cr,lf)
' enable measurement modes
hi2cout 0x80,(0x01) 'ALS Light
hi2cout 0x81,(0x03) 'PS Range

do
	w1 =0
	w2 = 0
	w3 = 0
	hi2cin 0x8c,(status)
	sertxd(#status,cr,lf)
	tmp1 = 0x01 & status
	if  tmp1 > 0 then 'PS is ready
		hi2cin 0x8d,(b6)
		hi2cin 0x8e,(b7)		
	endif
	tmp1 = 0x04 & status
	if  tmp1 > 0 then 'ALS is ready
		hi2cin 0x88,(b0,b1,b4,b5) ' throwing away the Ir (chan1) data
	endif	
	if w2 <5 and w3 <5 then
		'shutter is open in the dark
		low warning
	else
		high warning
	endif
	sertxd(#W2,"  ",#w3,cr,lf)
	pause 1000
loop
