# LINK TO TEAM VIDEO
# https://media.heanet.ie/page/8a8b5a3a448b433aa6b81df23c6f7ca7

  .syntax unified
  .cpu cortex-m4
  .fpu softvfp
  .thumb
  
  .global Main
  .global SysTick_Handler
  .global EXTI0_IRQHandler

  @ Definitions are in definitions.s to keep this file "clean"
  #include "definitions.S"

  .equ    BLINK_PERIOD, 800
  .equ    ANSWER_COUNTDOWN, 7500
  .equ    BLINK_PERIOD_ANSWER, ANSWER_COUNTDOWN / 8
  .equ    SLEEP_PERIOD, 1000
  .equ    SHOW_ROUND_PERIOD, 1000
  .equ    a, 5
  .equ    c, 1
  .equ    m, 8

  .section .text
  .type Main, %function
Main:
  PUSH  {R4-R5,LR}


  @
  @ Prepare GPIO Port E Pin 9 for output (LED LD3)
  @ We'll blink LED LD3 (the orange LED)
  @

  @ Enable GPIO port E by enabling its clock
  LDR     R4, =RCC_AHBENR
  LDR     R5, [R4]
  ORR     R5, R5, #(0b1 << (RCC_AHBENR_GPIOEEN_BIT))
  STR     R5, [R4]

  @ Configure LD3 for output
  @   by setting bits 27:26 of GPIOE_MODER to 01 (GPIO Port E Mode Register)
  @   (by BIClearing then ORRing)
  LDR     R4, =GPIOE_MODER
  LDR     R5, =0x55550000

  STR     R5, [R4]                      @ Write 

  @ Initialise the first countdown

  LDR     R4, =round_n
  MOV     R5, #0
  STR     R5, [R4]
  LDR     R4, =blink_countdown
  LDR     R5, =BLINK_PERIOD     // Giving the first countodown a little delay
  STR     R5, [R4]  

  LDR   R4, =answer_countdown
  LDR   R5, =ANSWER_COUNTDOWN
  STR   R5, [R4]

  LDR   R4, =sleep_countdown
  MOV   R5, #0
  STR   R5, [R4]

  LDR   R4, =i
  MOV   R5, #0
  STR   R5, [R4]
  



  @ Configure SysTick Timer to generate an interrupt every 1ms

  LDR   R4, =SCB_ICSR               @ Clear any pre-existing interrupts
  LDR   R5, =SCB_ICSR_PENDSTCLR     @
  STR   R5, [R4]                    @

  LDR   R4, =SYSTICK_CSR            @ Stop SysTick timer
  LDR   R5, =0                      @   by writing 0 to CSR
  STR   R5, [R4]                    @   CSR is the Control and Status Register
  
  LDR   R4, =SYSTICK_LOAD           @ Set SysTick LOAD for 1ms delay
  LDR   R5, =7999                   @ Assuming 8MHz clock
  STR   R5, [R4]                    @ 

  LDR   R4, =SYSTICK_VAL            @   Reset SysTick internal counter to 0
  LDR   R5, =0x1                    @     by writing any value
  STR   R5, [R4]

  LDR   R4, =SYSTICK_CSR            @   Start SysTick timer by setting CSR to 0x7
  LDR   R5, =0x7                    @     set CLKSOURCE (bit 2) to system clock (1)
  STR   R5, [R4]                    @     set TICKINT (bit 1) to 1 to enable interrupts
                                      @     set ENABLE (bit 0) to 1


  @
  @ Prepare external interrupt Line 0 (USER pushbutton)
  @ We'll count the number of times the button is pressed
  @

  @ Initialise count to zero
  LDR   R4, =button_count           @ count = 0;
  MOV   R5, #0                      @
  STR   R5, [R4]                    @
  LDR   R4, =waiting_for_user
  MOV   R5, #0
  STR   R5, [R4]

  @ Configure USER pushbutton (GPIO Port A Pin 0 on STM32F3 Discovery
  @   kit) to use the EXTI0 external interrupt signal
  @ Determined by bits 3..0 of the External Interrrupt Control
  @   Register (EXTIICR)
  LDR     R4, =SYSCFG_EXTIICR1
  LDR     R5, [R4]
  BIC     R5, R5, #0b1111
  STR     R5, [R4]

  @ Enable (unmask) interrupts on external interrupt Line0
  LDR     R4, =EXTI_IMR
  LDR     R5, [R4]
  ORR     R5, R5, #1
  STR     R5, [R4]

  @ Set falling edge detection on Line0
  LDR     R4, =EXTI_RTSR
  LDR     R5, [R4]
  ORR     R5, R5, #1
  STR     R5, [R4]

  LDR     R4, =EXTI_FTSR
  LDR     R5, [R4]
  ORR     R5, R5, #1
  STR     R5, [R4]

  @ Enable NVIC interrupt #6 (external interrupt Line0)
  LDR     R4, =NVIC_ISER
  MOV     R5, #(1<<6)
  STR     R5, [R4]

  @ Nothing else to do in MainK2B     Idle_Loop
  
End_Main:
  POP   {R4-R5,PC}

@
@ SysTick interrupt handler (blink LED LD3)
@
  .type  SysTick_Handler, %function
SysTick_Handler:
  PUSH  {R4-R7, LR}

  LDR   R4, =sleep_countdown        @ if (sleep_countdown > 0) {
  LDR   R5, [R4]                    @ 
  CMP   R5, #0                      @
  BLE   .LendIfSleeping             @
                                    @
  SUB   R5, R5, #1                  @   sleep_countdown -= 1
  STR   R5, [R4]                    @   return;
  B     .LretSystick                @
.LendIfSleeping:                    @ }
                                    @
  LDR   R4, =show_round             @ if (show_round) {
  LDR   R5, [R4]                    @
  CMP   R5, #0                      @
  BEQ   .LendIfShowRound            @
                                    @
  LDR   R4, =show_round_countdown   @   if (show_round_countdown > 0) {
  LDR   R5, [R4]                    @
  CMP   R5, #0                      @
  BLE   .LelseStopShowRound         @
  SUB   R5, R5, #1                  @       show_round_countdown -= 1
  STR   R5, [R4]                    @
  B     .LendIfStopShowRound        @
.LelseStopShowRound:                @   } else {
  BL    clear_lights                @       clear_lights()
  LDR   R4, =show_round             @       show_round = false
  MOV   R5, #0                      @
  STR   R5, [R4]                    @
  LDR   R4, =sleep_countdown        @       sleep_countdown = SLEEP_PERIOD
  LDR   R5, =SLEEP_PERIOD           @
  STR   R5, [R4]                    @
.LendIfStopShowRound:               @   }
  B     .LretSystick                @   return
.LendIfShowRound:                   @ }
                                    @
  LDR   R4, =waiting_for_user       @ if(waitingForUser)
  LDR   R5, [R4]                    @ {
  CMP   R5, #1
  BNE   .LcheckGame
  BL    wait_for_user
  B     .LretSystick                @ }
.LcheckGame:                        @ else {
  LDR   R4, =game_started           @   if(!game_started) {
  LDR   R5, [R4]                    @
  CMP   R5, #0                      @   
  BNE   .LelseGameStarted           @
                                    @
  LDR   R4, =button_is_pressed      @
  LDR   R5, [R4]                    @
  CMP   R5, #0                      @
  BEQ   .LelseNotPressed            @   if (button_is_pressed) {

  LDR   R4, =pressed_time           @
  LDR   R5, [R4]                    @
  ADD   R5, R5, #1                  @       pressed_time += 1
  STR   R5, [R4]                    @
  B     .LendIfPressed              @
.LelseNotPressed:                   @   } else {
  LDR   R4, =pressed_time           @       if (pressed_time > 0)
  LDR   R5, [R4]                    @           return
  CMP   R5, #0                      @
  BEQ   .LendIfPressed              @
                                    @
  MOV   R8, R5                      @       x0 = pressed_time
  LDR   R4, =random_value           @
  LDR   R5, [R4]                    @       n = random_value
                                    @
  MOV   R6, #0                      @   
.LwhGenLights:                      @       for (int i = 0; i < n; i++) {
  CMP   R6, R5
  BGE   .LendWhGenLights

  MOV   R7, #a
  MUL   R8, R8, R7                  @           x1 = x0 * a + c
  ADD   R8, R8, #c
  AND   R8, #7                      @           x1 = x1 & 7
                                    @           same as % 8
  LDR   R7, =random_lights
  STR   R8, [R7, R6, LSL #2]        @           word[random_lights] = x1

  ADD   R6, R6, #1                  @       // we are remembering the sequence
  B     .LwhGenLights
.LendWhGenLights:                   @       }
  LDR   R4, =game_started           @       game_started = 1
  MOV   R5, #1                      @
  STR   R5, [R4]                    @
                                    @
  BL    glow_round_number           @       glow_round_number()
  LDR   R4, =show_round             @       show_round = true
  MOV   R5, #1                      @
  STR   R5, [R4]                    @
  LDR   R4, =show_round_countdown   @       show_round_countdown = SHOW_ROUND_PERIOD
  LDR   R5, =SHOW_ROUND_PERIOD      @
  STR   R5, [R4]                    @
.LendIfPressed:                     @   }
  B     .LretSystick                @ return
.LelseGameStarted:                  @ } else {

  LDR   R4, =blink_countdown        @   if (blink_countdown != 0) {
  LDR   R5, [R4]                    @
  CMP   R5, #0                      @
  BEQ   .LelseFire                  @

  SUB   R5, R5, #1                  @       blink_countdown = blink_countdown - 1;
  STR   R5, [R4]                    @

  B     .LendIfDelay                @   }

.LelseFire:                         @   else {

  LDR   R4, =i
  LDR   R5, [R4]                    @   // R5: i

  LDR   R4, =random_value           
  LDR   R6, [R4]                    @   // random_value

  CMP   R5, R6                      @   if (i < random_value) {
  BGE   .LresetGame                 @ 

  LDR   R4, =random_lights
  LDR   R7, [R4, R5, LSL #2]        @       get current light offset
  ADD   R7, R7, #LD4_PIN            @

  MOV   R6, #1                      @       get current light bit
  LSL   R6, R6, R7                  @ 

  BL    clear_lights                @       clear_lights()

  LDR   R4, =GPIOE_ODR              @
  LDR   R5, [R4]
  ORR   R5, R6                      @       turn on current light
  STR   R5, [R4]                    @

  LDR   R4, =i                      @
  LDR   R5, [R4]                    @
  ADD   R5, R5, #1                  @       i += 1
  STR   R5, [R4]                    @
  B     .LskipResetGame             @
.LresetGame:                        @   } else {
  LDR   R4, =i                      @       i = 0
  MOV   R5, #0                      @
  STR   R5, [R4]                    @

  BL    clear_lights                @       clear_lights()

  LDR   R4, =game_started           @       game_started = 0
  MOV   R5, #0                      @
  STR   R5, [R4]                    @
                                    @
  LDR   R4, =waiting_for_user       @       waiting_for_user = true 
  MOV   R5, #1                      @
  STR   R5, [R4]                    @
                                    @
  LDR   R4, =pressed_time           @       pressed_time = 0
  MOV   R5, #0                      @
  STR   R5, [R4]                    @
                                    @
  LDR   R4, =sleep_countdown        @       sleep_countdown = SLEEP_PERIOD
  LDR   R5, =SLEEP_PERIOD           @
  STR   R5, [R4]                    @
.LskipResetGame:                    @   }
  LDR   R4, =blink_countdown        @
  LDR   R6, =round_n                @  
  LDR   R6, [R6]                    @
  MOV   R5, #100                  @     blink_countdown = BLINK_PERIOD - round_n * 100
  MUL   R6, R5, R6                  @
  LDR   R5, =BLINK_PERIOD           @
  SUB   R5, R5, R6                  @
  CMP   R5, #100                  @     if (blink_countdown < 100 {
  BGE   .LendIfTooFast              @       blink_coundown = 100
  MOV   R5, #100                  @     }
.LendIfTooFast:                     @
  STR   R5, [R4]                    @
                                    @
.LendIfDelay:                       @ }

.LretSystick:
  LDR     R4, =SCB_ICSR             @ Clear (acknowledge) the interrupt
  LDR     R5, =SCB_ICSR_PENDSTCLR   @
  STR     R5, [R4]                  @

  @ Return from interrupt handler
  POP  {R4-R7, PC}



@
@ External interrupt line 0 interrupt handler
@   (count button presses)
@
  .type  EXTI0_IRQHandler, %function
EXTI0_IRQHandler:

  PUSH  {R4-R7,LR}

  LDR   R4, =button_is_pressed
  LDR   R5, [R4]

  CMP   R5, #0                      @ if (!button_is_pressed) {
  BNE   .LnotReset

  LDR   R6, =waiting_for_user       @   if (waiting_for_user) {
  LDR   R7, [R6]                    @
  CMP   R7, #1                      @
  BNE   .LendIfWaiting              @
                                    @
  EOR   R5, #1                      @       button_is_pressed = !button_is_pressed
  STR   R5, [R4]                    @
                                    @
  LDR   R4, =button_count           @       button_count = button_count + 1
  LDR   R5, [R4]                    @
  ADD   R5, R5, #1                  @
  STR   R5, [R4]                    @
  B     .LretButtonHandler          @       return
.LendIfWaiting:                     @   }

  LDR   R6, =pressed_time           @
  MOV   R7, #0                      @
  STR   R7, [R6]                    @   pressed_time = 0
.LnotReset:                         @ }

  LDR   R6, =waiting_for_user       @ if (waiting_for_user) {
  LDR   R7, [R6]                    @
  CMP   R7, #1                      @

  EOR   R5, #1                      @   button_is_pressed = !button_is_pressed
  STR   R5, [R4]                    @
  BEQ   .LretButtonHandler          @   return
                                    @ }
  LDR   R4, =SYSTICK_VAL            @
  LDR   R5, [R4]                    @
  AND   R5, R5, #7                  @ random_value = (SYSTICK_VAL % 8) + 5
  ADD   R5, R5, #5                  @
  LDR   R4, =random_value           @
  STR   R5, [R4]                    @
  
.LretButtonHandler:
  LDR   R4, =EXTI_PR                @ Clear (acknowledge) the interrupt
  MOV   R5, #(1<<0)                 @
  STR   R5, [R4]                    @
  
  @ Return from interrupt handler
  POP  {R4-R7,PC}


@ turn off all lights
clear_lights:
  PUSH {R4-R6,LR}

  LDR   R4, =GPIOE_ODR
  LDR   R5, [R4]
  LDR   R6, =0xff00             
  BIC   R5, R6
  STR   R5, [R4]

  POP  {R4-R6,PC}
@ glows green
glow_win:
  PUSH  {R4-R5,LR}

  LDR   R4, =GPIOE_ODR
  LDR   R5, [R4]
  ORR   R5, #(0b1 << LD6_PIN)
  ORR   R5, #(0b1 << LD7_PIN)
  STR   R5, [R4]

  POP   {R4-R5,PC}
@ glows red
glow_lose:
  PUSH  {R4-R5,LR}

  LDR   R4, =GPIOE_ODR
  LDR   R5, [R4]
  ORR   R5, #(0b1 << LD3_PIN)
  ORR   R5, #(0b1 << LD10_PIN)
  STR   R5, [R4]

  POP   {R4-R5,PC}
@ shows the current round number
glow_round_number:
  PUSH  {R4-R6,LR}

  BL    clear_lights
  LDR   R4, =round_n
  LDR   R6, [R4]
  RSB   R6, R6, #7

  CMP   R6, #0
  BGE   .LendIfLargeRound
  MOV   R6, #0
.LendIfLargeRound:

  LDR   R4, =circle_bit_patterns
  LDRH  R6, [R4, R6, LSL #1]
  LDR   R5, =0xff00
  EOR   R6, R5
  
  LDR   R4, =GPIOE_ODR
  LDR   R5, [R4]
  ORR   R5, R6
  STR   R5, [R4]

  POP   {R4-R6,PC}

@ resets everything after waiting for user input
reset_awaiting_answer:
  PUSH  {R4-R5,LR}

  LDR   R4, =answer_countdown           @ answer_coundown = ANSWER_COUNTDOWN
  LDR   R5, =ANSWER_COUNTDOWN
  STR   R5, [R4]
  LDR   R4, =waiting_for_user           @ waiting_for_user = 0
  MOV   R5, #0
  STR   R5, [R4]
  LDR   R4, =button_count               @ button_count = 0
  MOV   R5, #0
  STR   R5, [R4]

  POP   {R4-R5,PC}

@ decreases answer_countdown and shows time left using lights
@ also checks if user won and glows correspondingly
wait_for_user:
  PUSH  {R4-R6,LR}

  LDR   R4, =answer_countdown           @   if(answer_countdown != 0)
  LDR   R5, [R4]                        @   {
  CMP   R5, #0   
  BEQ   .LendAnswerCount                @
  SUB   R5, R5, #1                      @     answerCountdown -= 1;
  STR   R5, [R4]                        @

  BL    clear_lights

  LDR   R6, =BLINK_PERIOD_ANSWER
  UDIV  R6, R5, R6
  ADD   R6, R6, #1
  LDR   R4, =circle_bit_patterns
  LDRH  R6, [R4, R6, LSL#1]
  
  LDR   R4, =GPIOE_ODR
  LDR   R5, [R4]
  ORR   R5, R6
  STR   R5, [R4]

  B     .LretWaitForUser
.LendAnswerCount:
  BL    clear_lights
  LDR   R4, =random_value               @ if (button_count = random_value)
  LDR   R5, [R4]
  LDR   R4, =button_count
  LDR   R6, [R4]
  CMP   R5, R6
  BNE   .LelseGameWrong
  BL    glow_win                       @ glow_win
  LDR   R4, =round_n        
  LDR   R5, [R4]
  ADD   R5, R5, #1
  STR   R5, [R4]
  B     .LendIfGameWrong
.LelseGameWrong:
  BL    glow_lose
.LendIfGameWrong:
  BL    reset_awaiting_answer

.LretWaitForUser:
  POP   {R4-R6,PC}

  .section .data
  
circle_bit_patterns:
  .hword 0b0000000000000000
  .hword 0b0000010000000000
  .hword 0b0000110000000000
  .hword 0b0001110000000000
  .hword 0b0011110000000000
  .hword 0b0111110000000000
  .hword 0b1111110000000000
  .hword 0b1111110100000000
  .hword 0b1111111100000000
button_count:
  .space  4
blink_countdown:
  .space  4
answer_countdown:
  .space  4
sleep_countdown:
  .space 4
show_round_countdown:
  .space 4
random_value:
  .space  4
game_started:
  .space  4
show_round:
  .space 4
waiting_for_user:
  .space 4
button_is_pressed:
  .space  4
pressed_time:
  .space  4
a:
  .space  4
c:
  .space  4
m:
  .space  4
random_lights:
  .space 400
i:
  .space 4
round_n:
  .space 4
  .end