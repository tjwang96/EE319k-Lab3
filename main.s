;****************** main.s ***************
; Program written by: ***Jason Wang and Rahul Banerjee***
; Date Created: 2/4/2017
; Last Modified: 1/17/2020
; Brief description of the program
;   The LED toggles at 2 Hz and a varying duty-cycle
; Hardware connections (External: One button and one LED)
;  PE1 is Button input  (1 means pressed, 0 means not pressed)
;  PE2 is LED output (1 activates external LED on protoboard)
;  PF4 is builtin button SW1 on Launchpad (Internal) 
;        Negative Logic (0 means pressed, 1 means not pressed)
; Overall functionality of this system is to operate like this
;   1) Make PE2 an output and make PE1 and PF4 inputs.
;   2) The system starts with the the LED toggling at 2Hz,
;      which is 2 times per second with a duty-cycle of 30%.
;      Therefore, the LED is ON for 150ms and off for 350 ms.
;   3) When the button (PE1) is pressed-and-released increase
;      the duty cycle by 20% (modulo 100%). Therefore for each
;      press-and-release the duty cycle changes from 30% to 70% to 70%
;      to 90% to 10% to 30% so on
;   4) Implement a "breathing LED" when SW1 (PF4) on the Launchpad is pressed:
;      a) Be creative and play around with what "breathing" means.
;         An example of "breathing" is most computers power LED in sleep mode
;         (e.g., https://www.youtube.com/watch?v=ZT6siXyIjvQ).
;      b) When (PF4) is released while in breathing mode, resume blinking at 2Hz.
;         The duty cycle can either match the most recent duty-
;         cycle or reset to 30%.
;      TIP: debugging the breathing LED algorithm using the real board.
; PortE device registers
GPIO_PORTE_DATA_R  EQU 0x400243FC
GPIO_PORTE_DIR_R   EQU 0x40024400
GPIO_PORTE_AFSEL_R EQU 0x40024420
GPIO_PORTE_DEN_R   EQU 0x4002451C
; PortF device registers
GPIO_PORTF_DATA_R  EQU 0x400253FC
GPIO_PORTF_DIR_R   EQU 0x40025400
GPIO_PORTF_AFSEL_R EQU 0x40025420
GPIO_PORTF_PUR_R   EQU 0x40025510
GPIO_PORTF_DEN_R   EQU 0x4002551C
GPIO_PORTF_LOCK_R  EQU 0x40025520
GPIO_PORTF_CR_R    EQU 0x40025524
GPIO_LOCK_KEY      EQU 0x4C4F434B  ; Unlocks the GPIO_CR register
SYSCTL_RCGCGPIO_R  EQU 0x400FE608
	
	
       IMPORT  TExaS_Init
       THUMB
       AREA    DATA, ALIGN=2
;global variables go here
Index  SPACE   4
Index2 SPACE   4
SaveLink SPACE 4
       AREA    |.text|, CODE, READONLY, ALIGN=2
       THUMB
	   EXPORT  Start
CArr   DCD	   2000000, 4670000, 3300000, 3300000, 4670000, 2000000, 5950000, 660000, 660000, 5950000 ;3000000, 7000000, 5000000, 5000000, 7000000, 3000000, 9000000, 1000000, 1000000, 9000000
Breath DCD	   15000/2, 135000/2, 45000/2, 105000/2, 75000/2, 75000/2, 105000/2, 45000/2, 135000/2, 15000/2
Start
 ; TExaS_Init sets bus clock at 80 MHz
     BL  TExaS_Init ; voltmeter, scope on PD3
	 LDR R0,=SYSCTL_RCGCGPIO_R		;turn on Port E and Port F clock
	 LDR R1,[R0]
	 ORR R1,#0x30
	 STR R1,[R0]
	 NOP
	 NOP
	 NOP
	 NOP
	 LDR R0,=GPIO_PORTE_DIR_R		;Set PE1 as input, PE3 as output
	 LDR R1,[R0]
	 ORR R1,#0x08
	 BIC R1,#0x02
	 STR R1,[R0]
	 LDR R0,=GPIO_PORTF_DIR_R		;Set PF4 as input
	 LDR R1,[R0]
	 BIC R1,#0x10
	 STR R1,[R0]
	 LDR R0,=GPIO_PORTE_DEN_R		;Digitally enable PE1 and PE3
	 LDR R1,[R0]
	 ORR R1,#0x0A
	 STR R1,[R0]
	 LDR R0,=GPIO_PORTF_DEN_R		;Digitally enable PF4
	 LDR R1,[R0]
	 ORR R1,#0x10
	 STR R1,[R0]
	 LDR R0,=GPIO_PORTF_LOCK_R		
	 LDR R1,=GPIO_LOCK_KEY
	 STR R1,[R0]
	 LDR R0,=GPIO_PORTF_CR_R
	 LDR R1,[R0]
	 ORR R1,#0xFF
	 STR R1,[R0]
	 LDR R0,=GPIO_PORTF_PUR_R		;Set Pull up resistor for PF4
	 LDR R1,[R0]
	 ORR R1,#0x11
	 STR R1,[R0]
	 LDR R8,=Index
	 MOV R1,#0
	 STR R1,[R8]
	 STR R1,[R8,#4]
	 LDR R9,=CArr
	 LDR R6,=Breath
	 LDR R10,=GPIO_PORTE_DATA_R		;Reserved Regs, R0-count R8-Index R9-Array R10-PortE R6-Breath R11-PortF R12-BackMask
	 LDR R11,=GPIO_PORTF_DATA_R	
     CPSIE  I    ; TExaS voltmeter, scope runs on interrupts
loop 
	 LDR R1,[R10]
	 BL  check
	 MOV R5,#1
	 MOV R12,#0
	 BL  breathingsr
	 LDR R1,[R10]
	 ORR R1,#0x08
	 STR R1,[R10]
	 LDR R7,[R8]
	 LDR R0,[R9,R7]		
	 BL  delay
	 LDR R1,[R10]
	 BIC R1,#0x08 
	 STR R1,[R10]
	 LDR R7,[R8]
	 ADD R7,#4
	 STR R7,[R8]
	 LDR R0,[R9,R7]
	 BL  delay
	 LDR R7,[R8]
	 SUB R7,#4
	 STR R7,[R8]
	 LDR R0,[R9,R7]
     B    loop
	 
check
	 AND R2,R1,#0x02
	 LSR R2,#1
	 CMP R2,#1
	 BNE skip
	 LDR R7,[R8]
	 CMP R7,#32
	 BEQ redo
	 ADD R7,#8
	 STR R7,[R8]
	 B   skip
redo
	 SUB R7,#32
	 STR R7,[R8]
skip
	 LDR R1,[R10]
	 AND R2,R1,#0x02
	 CMP R2,#0
	 BNE skip
	 BX  LR

breathingsr
	 LDR R1,=SaveLink
	 STR LR,[R1]
breathing
	 LDR R1,[R11]
	 AND R2,R1,#0x10
	 CMP R2,#0x10
	 BEQ done
	 
	 MOV R2,#12
sameduty
	 LDR R1,[R10]
	 ORR R1,#0x08
	 STR R1,[R10]
	 LDR R7,[R8,#4]
	 LDR R0,[R6,R7]
	 BL  delay
	 LDR R1,[R10]
	 BIC R1,#0x08
	 STR R1,[R10]
	 LDR R7,[R8,#4]
	 ADD R7,#4
	 STR R7,[R8,#4]
	 LDR R0,[R6,R7]
	 BL  delay
	 LDR R7,[R8,#4]
	 SUB R7,#4
	 STR R7,[R8,#4]
	 SUBS R2,#1
	 BNE sameduty
	 CMP R5,#1
	 BEQ continue
	 LDR R7,[R8,#4]
	 CMP R7,#32
	 BEQ setmask
	 CMP R7,#0
	 BEQ setmask
	 CMP R12,#1
	 BEQ subtract
	 BNE continue
setmask
	 EOR R12,#1
	 CMP R12,#1
	 BNE continue
subtract
	 SUB R7,#8
	 STR R7,[R8,#4]
	 B   breathing
continue
	 BIC R5,#1
	 ADD R7,#8
	 STR R7,[R8,#4]
	 B   breathing
done
	 LDR R1,=SaveLink
	 LDR LR,[R1]
	 BX  LR


delay
dloop
	 SUBS R0,#1
	 BNE  dloop
	 BX   LR
      
     ALIGN      ; make sure the end of this section is aligned
     END        ; end of file

