# LINK TO TEAM VIDEO
# https://

  .syntax unified
  .cpu cortex-m4
  .fpu softvfp
  .thumb
  
  .global Main
  .global SysTick_Handler
  .global EXTI0_IRQHandler

  @ Definitions are in definitions.s to keep this file "clean"
  #include "definitions.S"

  .equ    BLINK_PERIOD, 100 
  .equ    ANSWER_COUNTDOWN, 5000
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

  LDR     R4, =blink_countdown
  LDR     R5, =0
  STR     R5, [R4]  

  LDR   R4, =answer_countdown
  LDR   R5, =ANSWER_COUNTDOWN
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

  @ Nothing else to do in Main
  @ Idle loop forever (welcome to interrupts!!)
Idle_Loop:
  B     Idle_Loop
  
End_Main:
  POP   {R4-R5,PC}



@
@ SysTick interrupt handler (blink LED LD3)
@
  .type  SysTick_Handler, %function
SysTick_Handler:

  PUSH  {R4-R8, LR}

  LDR   R4, =waiting_for_user       @ if (waiting_for_user) {
  LDR   R5, [R4]                    @
  CMP   R5, #1                      @
  BNE   .LcheckGame                 @
  LDR   R4, =answer_countdown       @   if (answer_countdown != 0) {
  LDR   R5, [R4]                    @
  CMP   R5, #0                      @
  BEQ   .LendAnswerCount            @
  SUB   R5, R5, #1                  @     answer_countdown -= 1
  STR   R5, [R4]                    @
.LendAnswerCount:                   @   } else {
                                    @     // CHECK IF RIGHT ANSWER HERE
                                    @     // + SHOW THE NEXT ROUND CAN BE STARTED
                                    @     // (OR MAYBE NOT, JUST SHOW IF YOU ARE RIGHT, and that is 
                                    @     // when the next round can be started)
  LDR   R4, =answer_countdown       @
  LDR   R5, =ANSWER_COUNTDOWN       @     answer_countdown = ANSWER_COUNTDOWN
  STR   R5, [R4]                    @
  LDR   R4, =waiting_for_user       @     waiting_for_user = false
  MOV   R5, #0                      @
  STR   R5, [R4]                    @
  LDR   R4, =button_count           @     count = 0
  MOV   R5, #0                      @
  STR   R5, [R4]                    @
                                    @   }
  B     .LretSystick                @   return
.LcheckGame:                        @ }
  LDR   R4, =game_started           @ if (!game_started) {
  LDR   R5, [R4]                    @
  CMP   R5, #0                      @
  BNE   .LelseGameStarted           @
  LDR   R4, =button_is_pressed      @   if (button_is_pressed) {  
  LDR   R5, [R4]                    @
  CMP   R5, #0                      @
  BEQ   .LelseReleased              @
  LDR   R4, =pressed_time           @
  LDR   R5, [R4]                    @
  ADD   R5, R5, #1                  @     pressed_time += 1
  STR   R5, [R4]                    @
  B     .LendIfReleased             @
.LelseReleased:                     @   } else if (pressed_time > 0) {
  LDR   R4, =pressed_time           @
  LDR   R5, [R4]                    @
  CMP   R5, #0                      @
  BEQ   .LendIfPressed              @

  MOV   R8, R5                      @     x = pressed_time
  LDR   R4, =lights_count           @
  LDR   R5, [R4]                    @     n = lights_count

  MOV   R6, #0                      @   
.LwhGenLights:                      @     for (int i = 0; i < n; i++) {
  CMP   R6, R5                      @
  BGE   .LendWhGenLights            @

  MOV   R7, #a                      @
  MUL   R8, R8, R7                  @       x = x * a + c
  ADD   R8, R8, #c                  @
  AND   R8, #7                      @       x = x % 8
  LDR   R7, =random_lights          @
  STR   R8, [R7, R6, LSL #2]        @       random_lights[i] = x
  ADD   R6, R6, #1                  @
  B     .LwhGenLights               @
.LendWhGenLights:                   @     }
  LDR   R4, =game_started           @     game_started = 1
  MOV   R5, #1                      @
  STR   R5, [R4]                    @
.LendIfReleased                     @   }
  B     .LretSystick                @
.LelseGameStarted:                  @ } else {

  LDR   R4, =blink_countdown        @   if (blink_countdown != 0) {
  LDR   R5, [R4]                    @
  CMP   R5, #0                      @
  BEQ   .LelseFire                  @
  SUB   R5, R5, #1                  @     blink_countdown = blink_countdown - 1;
  STR   R5, [R4]                    @
  B     .LendIfDelay                @
.LelseFire:                         @   } else {

  LDR   R4, =i                      @     // load i
  LDR   R5, [R4]                    @
  LDR   R4, =lights_count           @     // load lights_count
  LDR   R6, [R4]                    @
  CMP   R5, R6                      @     if (i < lights_count) {
  BGE   .LresetGame                 @

  LDR   R4, =random_lights          @
  LDR   R7, [R4, R5, LSL #2]        @       cur_light_offset = random_lights[i]
  ADD   R7, R7, #LD4_PIN            @       cur_light = cur_light_offset + LD4_PIN
  MOV   R6, #1                      @
  LSL   R6, R7                      @       cur_light_bit = 1 << cur_light 

  LDR   R4, =GPIOE_ODR              @
  LDR   R5, [R4]                    @
  LDR   R7, =0xff00                 @
  BIC   R5, R7                      @       GPIOE_ODR = GPIOE_ODR & ~ 0xff00      // turn off all lights

  ORR   R5, R6                      @       GPIOE_ODR = GPIOE_ODR | cur_light_bit // turn on cur light
  STR   R5, [R4]                    @

  LDR   R4, =i                      @       i += 1
  LDR   R5, [R4]                    @
  ADD   R5, R5, #1                  @
  STR   R5, [R4]                    @
  B     .LskipResetGame             @ 
.LresetGame:                        @     } else {
  LDR   R4, =i                      @       i = 0
  MOV   R5, #0                      @
  STR   R5, [R4]                    @

  LDR   R4, =GPIOE_ODR              @       GPIOE_ODR = GPIOE_ODR & ~0xff00      // turn off all lights
  LDR   R5, [R4]                    @
  LDR   R7, =0xff00                 @
  BIC   R5, R7                      @
  STR   R5, [R4]                    @

  LDR   R4, =game_started           @       game_started = false
  MOV   R5, #0                      @
  STR   R5, [R4]                    @
  LDR   R4, =waiting_for_user       @       waiting_for_user = true
  MOV   R5, #1                      @
  STR   R5, [R4]                    @
  LDR   R4, =pressed_time           @       pressed_time = 0
  MOV   R5, #0                      @
  STR   R5, [R4]                    @
.LskipResetGame:                    @     }
  LDR   R4, =blink_countdown        @     blink_countdown = BLINK_PERIOD;
  LDR   R5, =BLINK_PERIOD           @
  STR   R5, [R4]                    @
.LendIfDelay:                       @   }
.LretSystick:                       @ }
  LDR     R4, =SCB_ICSR             @ Clear (acknowledge) the interrupt
  LDR     R5, =SCB_ICSR_PENDSTCLR   @
  STR     R5, [R4]                  @

  @ Return from interrupt handler
  POP  {R4-R8, PC}


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
  BNE   .LelseIsPressed
  LDR   R6, =waiting_for_user       @   if (waiting_for_user) {
  LDR   R7, [R6]                    @       
  CMP   R7, #1                      @
  BNE   .LelseNotWaiting            @
  LDR   R4, =button_count           @       count = count + 1
  LDR   R5, [R4]                    @
  ADD   R5, R5, #1                  @
  STR   R5, [R4]                    @
  B     .LendIfPressed              @
.LelseNotWaiting:                   @   } else {
  LDR   R6, =pressed_time           @       pressed_time = 0
  MOV   R7, #0                      @
  STR   R7, [R6]                    @   
  B     .LendIfPressed              @   }
.LelseIsPressed:                    @ } else if (!waiting_for_user) {
                                    @
  LDR   R6, =waiting_for_user       @
  LDR   R7, [R6]                    @
  CMP   R7, #1                      @
  BEQ   .LendIfPressed              @
                                    @
  LDR   R4, =SYSTICK_VAL            @   // load systick value 
  LDR   R5, [R4]                    @
  AND   R5, R5, #7                  @   random_value = (systick_val % 8) + 5
  ADD   R5, R5, #5                  @
  LDR   R4, =lights_count           @   lights_count = random_value
  STR   R5, [R4]                    @
.LendIfPressed:                     @ }
                                    @
  EOR   R5, #1                      @ button_is_pressed = !button_is_pressed
  STR   R5, [R4]                    @
.LretButtonHandler:
  LDR   R4, =EXTI_PR                @ Clear (acknowledge) the interrupt
  MOV   R5, #(1<<0)                 @
  STR   R5, [R4]                    @

  @ Return from interrupt handler
  POP  {R4-R7,PC}


  .section .data
  
button_count:
  .space  4

blink_countdown:
  .space  4

answer_countdown:
  .space  4

lights_count:
  .space  4

game_started:
  .space  4

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
  .end
