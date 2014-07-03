.include "m162def.inc"

.def Temp =r16
.def Temp2 =r19
.def Counter = R21
.def System = R22 ; 0 = FS20, 1 = XBEE
.def Err_Counter = R25
;.def Err_Clock = r24
; r24 = frei

.def last_Ruder = r20
.def verg = r23
.def data = r17
.def data2 = r18


.equ XTAL = 4000000
.equ F_CPU = 4000000                            ; Systemtakt in Hz
.equ BAUD  = 9600                               ; Baudrate
 
; Berechnungen
.equ UBRR_VAL   = ((F_CPU+BAUD*8)/(BAUD*16)-1)  ; clever runden
.equ BAUD_REAL  = (F_CPU/(16*(UBRR_VAL+1)))      ; Reale Baudrate
.equ BAUD_ERROR = ((BAUD_REAL*1000)/BAUD-1000)  ; Fehler in Promille
 
.if ((BAUD_ERROR>10) || (BAUD_ERROR<-10))       ; max. +/-10 Promille Fehler
  .error "Systematischer Fehler der Baudrate grösser 1 Prozent und damit zu hoch!"
.endif

.org 0x0000
        rjmp    Reset 


Reset:
ldi System, 2 
clr Err_Counter
;clr Err_Clock
ldi temp, 0
sts XBEE_AKTIV, temp
ldi temp, 3
sts COUNTER_B, temp


 ldi last_Ruder, 4
 ldi temp, 1 // verkürzt 
w_loop100:
          ldi Counter, 250           ; ca. 500ms warten
w_loop99:  ldi temp2, 132       
w_loop98:  dec temp2  
          brne w_loop98          
          dec Counter             
          brne w_loop99
          dec temp
          brne w_loop100

    LDI Temp, HIGH(RAMEND) ; Oberes Byte
    OUT SPH,Temp ; an Stapelzeiger
    LDI Temp, LOW(RAMEND) ; Unteres Byte
    OUT SPL,Temp ; an Stapelzeiger

 ; Baudrate einstellen
    ldi     temp, HIGH(UBRR_VAL)
    out     UBRR0H, temp
    out     UBRR1H, temp
    ldi     temp, LOW(UBRR_VAL)
    out     UBRR0L, temp
    out     UBRR1L, temp

      ;RS232 initialisieren A
    ldi r16, LOW(UBRR_VAL)
    out UBRR0L,r16
    ldi r16, HIGH(UBRR_VAL)
    out UBRR0H,r16
    ldi r16, (1<<URSEL0)|(3<<UCSZ00) ; Frame-Format: 8 Bit
    out UCSR0C,r16
    sbi UCSR0B, RXEN0            ; RX (Empfang) aktivieren
    sbi UCSR0B, TXEN0            ; TX (Senden)  aktivieren


      ;RS232 initialisieren B
    ldi r16, LOW(UBRR_VAL)
    out UBRR1L,r16
    ldi r16, HIGH(UBRR_VAL)
    out UBRR1H,r16
    ldi r16, (1<<URSEL1)|(3<<UCSZ10) ; Frame-Format: 8 Bit
    out UCSR1C,r16
    sbi UCSR1B, RXEN1            ; RX (Empfang) aktivieren
    sbi UCSR1B, TXEN1            ; TX (Senden)  aktivieren

ldi r16, 0x00
out DDRA, r16     ; Alle Pins am Port A durch Ausgabe von 0x00 ins
out DDRC, r16
                           ; Richtungsregister DDRA als Eingang konfigurieren
ldi r16, 0xFF     ; An allen Pins vom Port A die Pullup-Widerstände
out PORTA, r16    ; aktivieren. Dies geht deshalb durch eine Ausgabe
out PORTC, r16                          ; nach PORTA, da ja der Port auf Eingang gestellt ist.

ser Temp
out DDRB, Temp
out PORTB, Temp

in verg, PINA ; soll alte zustände speichern
; Hauptschleife
timer0:


; System überprüfen
sbic PINC, 0x02 ; XBEE
rjmp n_FS20
cpi System, 1
breq n_FS20
; umstellen auf XBEE
sbi PORTB, 0x00
rcall Umstellen_XBEE
rjmp Weiter
n_FS20:
sbis PINC, 0x02 ; FS20
rjmp n_XBEE
cpi System, 0
breq n_XBEE
; umstellen auf FS20
sbi PORTB, 0x00
rcall Umstellen_FS20
rjmp Weiter
n_XBEE:

; Ping überprüfen/senden
cpi System, 0
breq no_Ping
; Ping empfangen
sbis     UCSR0A, RXC0                     
rjmp     no_ping_receive
in       Err_Counter, UDR0
//lds temp, XBEE_AKTIV
//cpi temp, 0
//brne no_reset
//in verg, PINA
//ldi last_Ruder, 4
; alle nochmal senden
no_reset:

ldi temp, 255
sts XBEE_AKTIV, temp

cpi Err_Counter, 'Z'
brne no_ping_receive
; Ping empfangen
cbi PORTB, 0x06
no_ping_receive:


; Ping senden
lds temp, COUNTER_A
dec temp
sts COUNTER_A, temp
cpi temp, 0
brne no_ping

;lds temp, COUNTER_B
;dec temp
;sts COUNTER_B, temp
;cpi temp,0
;brne no_ping
;ldi temp, 2
;sts COUNTER_B, temp

; XBEE Fehler LED
cpi Err_Counter, 0
brne no_failure
sbi PORTB, 0x06
ldi temp, 0 ; Verbindung abgebrochen
sts XBEE_AKTIV, temp

no_failure:

cbi PORTB, 0x00
ldi Err_Counter,0
ldi temp, 'Z'
rcall serout  
rcall wait_25ms
rcall wait_25ms
sbi PORTB, 0x00
;rjmp Weiter
no_ping:



; Ruder überprüfen
; Mitte
sbis PINC, 0
rjmp e1
sbis PINC, 1
rjmp e1

cpi last_Ruder, 1
breq e1
ldi last_ruder,1
cpi System, 0
breq FS_20_R_M
ldi     zl,low(SERVO_XBEE_M*2);  ; XBEE         
ldi     zh,high(SERVO_XBEE_M*2);
rjmp Warten
FS_20_R_M:
ldi     zl,low(SERVO_M*2); ; FS20         
ldi     zh,high(SERVO_M*2);
rjmp Warten
e1:

; Links
sbic PINC, 0
rjmp e2
cpi last_Ruder, 0
breq e2
ldi last_ruder,0
cpi System, 0
breq FS_20_R_L
ldi     zl,low(SERVO_XBEE_L*2);  ; XBEE         
ldi     zh,high(SERVO_XBEE_L*2);
rjmp Warten
FS_20_R_L:
ldi     zl,low(SERVO_L*2);   ; FS20           
ldi     zh,high(SERVO_L*2);
rjmp Warten
e2:

; Rechts
sbic PINC, 1
rjmp e3
cpi last_Ruder, 2
breq e3
ldi last_ruder,2
cpi System, 0
breq FS_20_R_R
ldi     zl,low(SERVO_XBEE_R*2);  ; XBEE         
ldi     zh,high(SERVO_XBEE_R*2);
rjmp Warten
FS_20_R_R:
ldi     zl,low(SERVO_R*2);     ; FS20        
ldi     zh,high(SERVO_R*2);
rjmp Warten
e3:

// SM8
in r12, PINA
com r12
;clr data
ldi data, (1<<0x00)

clr temp2 // springer zurücksetzen
Schleife:

mov data2, verg
mov r10, r12
eor data2, r10

and data2, data
breq end ; wenn eingang und ausgang nicht unterschiedlich
mov r10, r12
and r10, data

breq w1 
// Einschalten setzen

or verg, data

rjmp Gesetzt


w1: 
// Ausschalten setzen
inc temp2

com verg
or verg, data
com verg

rjmp Gesetzt

end:

inc temp2
inc temp2
lsl data

brne Schleife


Weiter:
;ser Temp
;out PORTB, Temp
;out PORTA, Temp
sbi PORTB, 0x00

ldi Counter, 25           ; 2.5 Millisekunde warten
w_loop2:  ldi temp2, 132         
w_loop1:  dec temp2               
          brne w_loop1          
          dec Counter              
          brne w_loop2  

rjmp Timer0

Gesetzt:

// Senden
cpi System, 0
breq FS_20_SS
ldi     zl,low(XBEE*2);            
ldi     zh,high(XBEE*2);
// Springen
ldi temp, 0
cp temp2, temp
breq Warten

Spring2:
adiw    zl:zh,1
dec Temp2
brne Spring2

rjmp Warten
FS_20_SS:
ldi     zl,low(DATEN*2);            
ldi     zh,high(DATEN*2);
// Springen
ldi temp, 0
cp temp, temp2
breq Warten

Spring:
adiw    zl:zh,11             
dec Temp2
brne Spring



Warten:
ldi Err_Counter,0 ; Counter zurücksetzen
cbi PORTB, 0x00
cpi System, 0
breq FS_20_Send
lpm
mov temp, r0
rcall serout  
rcall wait_25ms
rcall wait_25ms
rjmp Weiter
FS_20_Send:
rcall   serout_string
;; warten
ldi temp, 20
w_loop7: 
ldi Counter, 100   
        ; 200 Millisekunde warten
w_loop6:  ldi temp2, 132          ;

w_loop5:  dec temp2             
          brne w_loop5 
          dec Counter              
          brne w_loop6

          dec temp
          brne w_loop7
rjmp Weiter

; String senden
serout_string:
push temp
ldi temp, 12
serout_string2:
    lpm                             ; nächstes Byte aus dem Flash laden
    ;and     r0,r0  
    dec temp                ; = Null? 
    breq    serout_string_ende      ; wenn ja, -> Ende
serout_string_wait:
    
    sbis    UCSR1A,UDRE1              ; Warten bis UDR für das nächste
                                    ; Byte bereit ist
    rjmp    serout_string_wait
    out     UDR1, r0
    adiw    zl:zh,1                 ; Zeiger erhöhen
    rjmp    serout_string2           ; nächstes Zeichen bearbeiten
serout_string_ende:
pop temp
    ret  

; Zeichen senden
serout:
    sbis    UCSR0A,UDRE0                  ; Warten bis UDR für das nächste
                                        ; Byte bereit ist
    rjmp    serout
    out     UDR0, temp
    ret    
    
; Sync
    sync:
    ldi     r16,0
sync_1:
    ldi     r17,0
sync_loop:
    dec     r17
    brne    sync_loop
    dec     r16
    brne    sync_1  
    ret    

; auf FS20 umstellen
 Umstellen_FS20:
 cpi System, 1 ; X Befehl senden, wenn altes System XBEE ist
brne no_X
ldi temp, 'X'
rcall serout
rcall wait_25ms
rcall wait_25ms
rcall wait_25ms
rcall wait_25ms
no_X:

 ldi System, 0
 clr Err_Counter
;clr Err_Clock
sbi PORTB, 0x05
rcall wait_25ms
cbi PORTB, 0x01
sbi PORTB, 0x06
cbi PORTB, 0x04
in verg, PINA
ldi last_Ruder, 4
; 500ms warten
ldi temp, 20
w_500:
rcall wait_25ms
dec temp
brne w_500
sbi PORTB, 0x00  


ldi     zl,low(SERVO_M*2);           
ldi     zh,high(SERVO_M*2);
rjmp Warten
 ret

 ; auf XBEE umstellen
 Umstellen_XBEE:
 ldi System, 1
 clr Err_Counter
;clr Err_Clock
sbi PORTB, 0x01
rcall wait_25ms
cbi PORTB, 0x05
sbi PORTB, 0x06
sbi PORTB, 0x04
in verg, PINA
ldi last_Ruder, 4
ldi temp, 255
sts XBEE_AKTIV, temp


; 50ms warten
ldi temp, 2
w2_2500:
rcall wait_25ms
dec temp
brne w2_2500  
sbi PORTB, 0x00

 ret


 wait_25ms:
push temp
ldi Counter, 250   
        ; 25 Millisekunde warten
w_loop22:  ldi temp, 132     
w_loop21:  dec temp          
          brne w_loop21 
          dec Counter              
          brne w_loop22     
pop temp
 ret





;             MOTOR_I_AN:                                            MOTOR_I_AUS:                                           MOTOR_II_AN:                                           MOTOR_II_AUS:                                          LICHT_AN:                                              LICHT_AUS:                                             KAMERA_AN:                                             KAMERA_AUS:                                            TURM_L_AN:                                             TURM_L_AUS:                                            TURM_R_AN:                                             TURM_R_AUS:                                            SPEED_I_AN:                                            SPEED_I_AUS:                                           SPEED_II_AN:                                           SPEED_II_AUS:
DATEN:    .db 0x02,0x06,0xf1,0x2f,0x39,0x00,0x10,0x02,0x00,0x00,0x00,0x02,0x06,0xf1,0x2f,0x39,0x00,0x00,0x02,0x00,0x00,0x00,0x02,0x06,0xf1,0x2f,0x39,0x02,0x10,0x02,0x00,0x00,0x00,0x02,0x06,0xf1,0x2f,0x39,0x02,0x00,0x02,0x00,0x00,0x00,0x02,0x06,0xf1,0x2f,0x39,0x11,0x10,0x02,0x00,0x00,0x00,0x02,0x06,0xf1,0x2f,0x39,0x11,0x00,0x02,0x00,0x00,0x00,0x02,0x06,0xf1,0x2f,0x39,0x13,0x10,0x02,0x00,0x00,0x00,0x02,0x06,0xf1,0x2f,0x39,0x13,0x00,0x02,0x00,0x00,0x00,0x02,0x06,0xf1,0x2f,0x39,0x21,0x10,0x02,0x00,0x00,0x00,0x02,0x06,0xf1,0x2f,0x39,0x21,0x00,0x02,0x00,0x00,0x00,0x02,0x06,0xf1,0x2f,0x39,0x23,0x10,0x02,0x00,0x00,0x00,0x02,0x06,0xf1,0x2f,0x39,0x23,0x00,0x02,0x00,0x00,0x00,0x02,0x06,0xf1,0x2f,0x39,0x30,0x10,0x02,0x00,0x00,0x00,0x02,0x06,0xf1,0x2f,0x39,0x30,0x00,0x02,0x00,0x00,0x00,0x02,0x06,0xf1,0x2f,0x39,0x32,0x10,0x02,0x00,0x00,0x00,0x02,0x06,0xf1,0x2f,0x39,0x32,0x00,0x02,0x00,0x00,0x00
RESET_ALL:.db 0x02,0x01,0xf6

SERVO_L:       .db 0x02,0x06,0xf1,0x2e,0x38,0x00,0x00,0x02,0x00,0x00,0x00
SERVO_M:       .db 0x02,0x06,0xf1,0x2e,0x38,0x00,0x08,0x02,0x00,0x00,0x00
SERVO_R:       .db 0x02,0x06,0xf1,0x2e,0x38,0x00,0x10,0x02,0x00,0x00,0x00

XBEE:          .db 'A', 'a', 'B', 'b', 'C', 'c', 'D', 'd', 'F', 'f', 'E', 'e', 'G', 'g', 'H', 'h'
SERVO_XBEE_L:  .db 'L'
SERVO_XBEE_M:  .db 'M'
SERVO_XBEE_R:  .db 'R'

.DSEG ; Arbeitsspeicher
XBEE_AKTIV:           .BYTE 1
COUNTER_A:            .BYTE 1
COUNTER_B:            .BYTE 1
