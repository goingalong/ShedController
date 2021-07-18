#rem
Shutter 'open' detector. Uses LTR-559 sensor to detect that the shutter is raised and that it is dark - 
	hence that the shutter has probably been left open at night.
	Outputs a high signal to indicate this state so that the seperate door/light controller
	can turn on the outside light as a warning indication.
July 2021 modifications force the light to stay on, once triggered, until reset by door closure.
#endrem
#picaxe 08m2
#no_data
symbol tmp1 = b0 'w0
symbol tmp2 = b1
symbol  status = b2 'w1
symbol tmp3 = b3
symbol lux = w2
symbol lux1 =  b4 'w2
symbol lux2 = b5
symbol range = w3
symbol range1 = b6 'w3
symbol range2 = b7
symbol warn_lock = b8 'true to lock the warning on
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
hi2cout 0x80,(0x01) 'ALS Lux
hi2cout 0x81,(0x03) 'PS Range

do
	w1 =0
	lux = 0
	range = 0
	hi2cin 0x8c,(status)
	sertxd(#status,cr,lf)
	tmp1 = 0x01 & status
	if  tmp1 > 0 then 'PS is ready
		hi2cin 0x8d,(range1)
		hi2cin 0x8e,(range2)		
	endif
	tmp1 = 0x04 & status
	if  tmp1 > 0 then 'ALS is ready
		hi2cin 0x88,(b0,b1,lux1,lux2) ' throwing away the Ir (chan1) data
	endif	
	if lux <5 and range <5 then
		'shutter is open in the dark
		warn_lock = 1
		low warning
	endif

	if range >=6 then
		'shutter is closed
		warn_lock = 0
	endif

	'control the exterior shed light
	if warn_lock = 1 then
		low warning 'raise output
	else
		high warning 'lower output
	endif

	pause 1000
loop
