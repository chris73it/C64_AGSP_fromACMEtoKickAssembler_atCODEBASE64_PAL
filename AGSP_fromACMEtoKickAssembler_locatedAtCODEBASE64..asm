//This demonstrates AGSP (any given screen position). This uses HSP (Horizontal Screen Positioning)
//(DMA delay) with a stable raster plus a line crunch to scroll the screen vertically to any position.

//Use a joystick in port two to move the screen around.

//The top five and a bit lines are "wasted" by the line crunch, if you see any demos with the top
//few lines blanked out and the screen below is moving at a fast rate then you can probably guess
//it is using a similar method.

//!to "RasterTest.prg", cbm
//!cpu 6510
//!ct pet

.label ZPProcessorPortDDR			= $00
.label ProcessorPortDDRDefault		= %101111
.label ZPProcessorPort			    = $01
.label ProcessorPortAllRAMWithIO	= %100101
.label CIA1InterruptControl			= $dc0d
.label CIA1TimerAControl			= $dc0e
.label CIA1TimerBControl			= $dc0f
.label CIA2InterruptControl			= $dd0d
.label CIA2TimerAControl			= $dd0e
.label CIA2TimerBControl			= $dd0f
.label VIC2InteruptControl			= $d01a
.label VIC2InteruptStatus			= $d019
.label VIC2BorderColour			    = $d020
.label VIC2ScreenColour			    = $d021
.label VIC2ScreenControlV			= $d011
.label VIC2SpriteEnable			    = $d015
.label VIC2Raster				    = $d012
.label CIA1KeyboardColumnJoystickA	= $dc00
.label KERNALNMIServiceRoutineLo	= $fffa
.label KERNALNMIServiceRoutineHi	= $fffb
.label KERNALIRQServiceRoutineLo	= $fffe
.label KERNALIRQServiceRoutineHi	= $ffff
.label VIC2Colour_Black             = 0
.label VIC2Colour_Red               = 2
.label VIC2Colour_Green             = 5

.macro MACROAckRasterIRQ_A() {
	lda #1
	sta VIC2InteruptStatus	//Ack Raster interupt
}

.macro MACROAckAllIRQs_A() {
	//Ack any interrupts that might have happened from the CIAs
	lda CIA1InterruptControl
	lda CIA2InterruptControl
	//Ack any interrupts that have happened from the VIC2
	lda #$ff
	sta VIC2InteruptStatus
}

/*
*= $0801
.byte $0b,$08,$01,$00,$9e		//Line 1 SYS2061
//.convtab pet
//!tx "2061"						//Address for sys start in text
.byte $00,$00,$00
*/

//!zn
.label theLine = 45
:BasicUpstart2(main)
main:
	//Stop interrupts, clear decimal mode and backup the previous stack entries
	lda #ProcessorPortAllRAMWithIO
	sei
	cld
	//Grab everything on the stack
	ldx #$ff
	txs
	//Init the processor port
	ldx #ProcessorPortDDRDefault
	stx ZPProcessorPortDDR
	//Set the user requested ROM state
	sta ZPProcessorPort
	//Clear all CIA to known state, interrupts off.
	lda #$7f
	sta CIA1InterruptControl
	sta CIA2InterruptControl
	lda #0
	sta VIC2InteruptControl
	sta CIA1TimerAControl
	sta CIA1TimerBControl
	sta CIA2TimerAControl
	sta CIA2TimerBControl
	:MACROAckAllIRQs_A()

	//Setup kernal and user mode IRQ vectors to point to a blank routine
	lda #<initIRQ
	sta KERNALIRQServiceRoutineLo
	lda #>initIRQ
	sta KERNALIRQServiceRoutineHi

	lda #<initNMI
	sta KERNALNMIServiceRoutineLo
	lda #>initNMI
	sta KERNALNMIServiceRoutineHi

	//Turn off various bits in the VIC2 and SID chips
	//Screen, sprites and volume are disabled.
	lda #0
	sta VIC2ScreenColour
	sta VIC2BorderColour
	sta VIC2ScreenControlV
	sta VIC2SpriteEnable

	//Setup raster IRQ
	lda #<IrqTopOfScreen
	sta KERNALIRQServiceRoutineLo
	lda #>IrqTopOfScreen
	sta KERNALIRQServiceRoutineHi
	lda #1
	sta VIC2InteruptControl
	lda #theLine
	sta VIC2Raster
	lda #$1b
	sta VIC2ScreenControlV

	lda #VIC2Colour_Red
	sta VIC2BorderColour

	:MACROAckAllIRQs_A()

	ldx #39
fs1:
	lda #$30
	sta $400 + 00*40 ,x
	sta $400 + 10*40 ,x
	sta $400 + 20*40 ,x
	lda #$31
	sta $400 + 01*40 ,x
	sta $400 + 11*40 ,x
	sta $400 + 21*40 ,x
	lda #$32
	sta $400 + 02*40 ,x
	sta $400 + 12*40 ,x
	sta $400 + 22*40 ,x
	lda #$33
	sta $400 + 03*40 ,x
	sta $400 + 13*40 ,x
	sta $400 + 23*40 ,x
	lda #$34
	sta $400 + 04*40 ,x
	sta $400 + 14*40 ,x
	sta $400 + 24*40 ,x
	lda #$35
	sta $400 + 05*40 ,x
	sta $400 + 15*40 ,x
	lda #$36
	sta $400 + 06*40 ,x
	sta $400 + 16*40 ,x
	lda #$37
	sta $400 + 07*40 ,x
	sta $400 + 17*40 ,x
	lda #$38
	sta $400 + 08*40 ,x
	sta $400 + 18*40 ,x
	lda #$39
	sta $400 + 09*40 ,x
	sta $400 + 19*40 ,x

	dex
	bpl fs1

	cli
mainLine:
	//Wait for the top IRQ to be triggered
	lda topIRQDone
	beq mainLine

	lda #0
	sta topIRQDone

	lda #%00001
	bit CIA1KeyboardColumnJoystickA
	bne notUp
	ldx yPosOffset
	inx
	cpx #26
	bne s1
	ldx #25
s1:
	stx yPosOffset
notUp:
	lda #%00010
	bit CIA1KeyboardColumnJoystickA
	bne notDown
	ldx yPosOffset
	dex
	bpl s2
	ldx #0
s2:
	stx yPosOffset
notDown:
	//If fire is not pressed then don't update the counter
	lda #%01000
	bit CIA1KeyboardColumnJoystickA
	bne notLeft
	ldx xPosOffset
	inx
	cpx #40
	bne o1
	ldx #39
o1:
	stx xPosOffset

notLeft:
	lda #%00100
	bit CIA1KeyboardColumnJoystickA
	bne notRight
	ldx xPosOffset
	dex
	bpl o2
	ldx #0
o2:
	stx xPosOffset

notRight:
	jmp mainLine

topIRQDone: .byte 0
xPosOffset: .byte 0
yPosOffset: .byte 0

//Remove all possibility that the timings will change due to previous code
.align $100 //255,0
IrqTopOfScreen:
	//Line 45
	pha
	txa
	pha
	tya
	pha

	inc topIRQDone

	lda #<irq2
	ldx #>irq2

	sta KERNALIRQServiceRoutineLo
	stx KERNALIRQServiceRoutineHi
	inc VIC2Raster
	:MACROAckRasterIRQ_A()

	//Begin the raster stabilisation code
	tsx
	cli
	//These nops never really finish due to the raster IRQ triggering again
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
irq2:
	//Line 46
	txs

	//Delay for a while
	ldx #8
l1:
	dex
	bne l1
	bit $ea

	//Final cycle wobble check.
	lda VIC2Raster
	cmp VIC2Raster
	beq start
start:

	//The raster is now stable

	//Line 47
	lda #$11
	sta VIC2ScreenControlV

	//Waste some time
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	bit $ea

	//Still in line 47
	//Calculate a variable offset to delay by branching over nops
	lda #39
	sec
	sbc xPosOffset
	//divide by 2 to get the number of nops to skip
	lsr
	sta sm1+1
	//Force branch always
	clv

	//Line 48

	//Introduce a 1 cycle extra delay depending on the least significant bit of the x offset
	bcc sm1
sm1:
	bvc *
	//The above branches somewhere into these nops depending on the x offset position
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop

	//Show the raster position is stable and varies as a function of x offset
	//If these border colour changes are removed then they need to be replaced with the same
	//cycle count of nops
	inc VIC2BorderColour
	dec VIC2BorderColour

	//Do the HSP by tweaking the VIC2ScreenControlV register at the correct time
	lda #%01111011	//Plus ECM/Bitmap to disable the screen output
//    lda #%00011011	//Enable this line to see what is going on at the top of the screen
	dec VIC2ScreenControlV
	inc VIC2ScreenControlV
	sta VIC2ScreenControlV

	//Change the below to "!if 0" to turn off the line crunch
.if (true) {
	//Display a red border at the start of this routine
	lda #VIC2Colour_Red
	sta VIC2BorderColour

	//The number of lines to crunch
	ldy yPosOffset
	beq s3

	//The raster line to start crunching on
	ldx #67
crunchLoop:
	//Load the next screen value
	lda table-67,x
	//Wait for the line...
	cpx VIC2Raster
	bne *-3
	//Produces a one line crunch
	//The timing of this store is quite critical, hence why the load is done before the raster line test
	sta VIC2ScreenControlV
	inx
	dey
	bne crunchLoop

	//Display green until the screen is enabled
	lda #VIC2Colour_Green
	sta VIC2BorderColour

s3:

	//Turn off ECM/Bitmap to enable the screen
	lda VIC2ScreenControlV
	and #%00011111
	//Wait for this raster line
	ldx #67+26
	cpx VIC2Raster
	bne *-3
	//Enable the screen
	sta VIC2ScreenControlV

	lda #VIC2Colour_Black
	sta VIC2BorderColour
} else {
	lda #%00011011
	sta VIC2ScreenControlV
}

	//Restart the IRQ chain
	lda #<IrqTopOfScreen
	ldx #>IrqTopOfScreen
	ldy #theLine
	sta KERNALIRQServiceRoutineLo
	stx KERNALIRQServiceRoutineHi
	sty VIC2Raster
	:MACROAckRasterIRQ_A()

	//Exit the IRQ
	pla
	tay
	pla
	tax
	pla
initIRQ:
initNMI:
	rti

//With ECM + bitmap enabled to turn off the top of the screen
table:
.byte %01111100
.byte %01111101
.byte %01111110
.byte %01111111
.byte %01111000
.byte %01111001
.byte %01111010
.byte %01111011

.byte %01111100
.byte %01111101
.byte %01111110
.byte %01111111
.byte %01111000
.byte %01111001
.byte %01111010
.byte %01111011

.byte %01111100
.byte %01111101
.byte %01111110
.byte %01111111
.byte %01111000
.byte %01111001
.byte %01111010
.byte %01111011

.byte %01111100
.byte %01111101
.byte %01111110
.byte %01111111
.byte %01111000
.byte %01111001
.byte %01111010
.byte %01111011