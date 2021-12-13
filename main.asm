;CABECERA----------------------------------------------------------------------

RES_VECT  CODE    0x0000            ; processor reset vector
    GOTO    START                   ; go to beginning of program
    ORG 0x04
	GOTO RUT_INTERR

; TODO ADD INTERRUPTS HERE IF USED

MAIN_PROG CODE                      ; let linker place main program
 
;VARIABLES----------------------------------------------------------------------
 NRO_CARRERAS EQU 0x20
 CIFRA_HEXENA EQU 0x22
 CIFRA_UNIDAD EQU 0x23
 SSEG_HEXENA EQU 0x1A0; FSR 0001 1001 0000
 SSEG_UNIDAD EQU 0x1A1; FSR 0001 1001 0001:solo cambia el bit menos signif
 COPIA_NRO_CARRERAS EQU 0x27;
 
;CONFIGURACIONES----------------------------------------------------------------------
 CONFIG_TMR1:;cada 60 seg
    RETURN;
    
 CONFIG_RB0:
    BANKSEL OPTION_REG;
    BSF OPTION_REG, INTED;
    BANKSEL INTCON;
    BSF INTCON, INTE;
    BSF INTCON, GIE;
    RETURN;
    
 CONFIG_TMR0:;cada 33ms osea 50HZ
    RETURN;
    
 CONFIG_PINES_PANTALLA:
    RETURN;
 
INCIALIZO_VARIABLES:
    CLRF NRO_CARRERAS;
    CLRF CIFRA_HEXENA
    CLRF CIFRA_UNIDAD
    CLRF SSEG_HEXENA
    CLRF SSEG_UNIDAD
    
    MOVLW 0x1A0; inicializo el puntero FSR a la variable SSEG_HEXENA
    MOVWF FSR;
    CLRF PORTB;
    MOVLW B'0000001';por defecto seleccionada la pantalla de la decena
    MOVWF PORTD;
    RETURN;
    
 CONFIGS:
    CALL INCIALIZO_VARIABLES;
    
    CALL CONFIG_RB0;cuando el piston completa la carrera se produce la interrupcion en el pin rb0
    CALL CONFIG_TMR0;para el refresco de las pantallas 33ms
    CALL CONFIG_PINES_PANTALLA;puerto d como salida, solamente el pin RD0 del puerto D para seleccionar las pantallas usando un circuito decodificador de 1 bit.
    
    RETURN;
;RUTINA DE INTERR----------------------------------------------------------------------
 RUT_INTERR:
    ;GUARDAS CONTEXTO
    
    BTFSC INTCON, T0IF;pregunta si llamo el timer 0 cada 33ms
    CALL REFRESCO_DISPLAY;
    BTFSC INTCON, INTF;pregunta si salto la bandera de rb0 osea el piston completo carrera.
    CALL CONTAR_CARRERA;
    
    ;RESTAURAR CONTEXTO
    RETFIE
;FUNCIONES----------------------------------------------------------------------
 CONTAR_CARRERA:
    ;por consigna el maximo de carreras del piston antes del mantenimiento es 200 carreras
    BCF INTCON, INTF;
    INCF NRO_CARRERAS;
    RETURN;
    

 CALCULAR_CIFRAS_HEXA:
    ;F(hexena)F(unidad) 
    ;va a cargar el valor decimal correspondiente
    ; CIFRA_HEXENA, CIFRA_UNIDAD
    CLRF CIFRA_HEXENA;
    CLRF CIFRA_UNIDAD;
    MOVFW NRO_CARRERAS;110
    MOVWF COPIA_NRO_CARRERAS;110
 CICLO
    MOVFW COPIA_NRO_CARRERAS;14
    MOVWF CIFRA_UNIDAD; 14
    MOVLW .16;
    SUBWF COPIA_NRO_CARRERAS, F;-2
    BTFSS STATUS, C;
    RETURN;
    INCF CIFRA_HEXENA;6
    GOTO CICLO;
    RETURN;   
 
 TABLA_HEXA_7SEG:
    ;comvierte el valor BCD que viene en W a codigo de 7 seg CATODO COMUN!!!
    ADDWF PCL, F;
    RETLW B'00000110';0
    RETLW B'01111011';1
    ;
    ;
    ;
    ;
    ;
    RETLW B'01111011';E
    RETLW B'01111011';F
    
 CALCULAR_CODIGOS_7SEG:
    ;teniendo en cuenta los valores de CIFRA_DECENA, CIFRA_UNIDAD
    ;convertirlos en codigo de 7segmentos y cargarlos en 
    ; estas variables SSEG_DECENA(0x1A0) y SSEG_UNIDAD(0x1A1)
    MOVFW CIFRA_HEXENA; cargo el valor en w para que consulte la tabla
    CALL TABLA_HEXA_7SEG; consulta la tabla y trae el valor en w
    MOVWF SSEG_HEXENA;
    MOVFW CIFRA_UNIDAD;
    CALL TABLA_HEXA_7SEG
    MOVWF SSEG_UNIDAD;
    RETURN;
 
    
 REFRESCO_DISPLAY:;se ejecuta cada 33ms
    BCF INTCON, T0IF;
    MOVLW 0.XX;
    MOVWF TMR0;reestablezco el valor del registro para que vuelva a interr en 33ms
    ;como tengo dos displays de 7seg necesito calcular las dos cifras/digitos hexadecimales para mostrar
    ;en la pantalla, adicionalmente estas cifras decimales deben convertirse a el codigo de 7seg.
    ;coloco el valor corresponeidte en el puerto D
    ;y tengo que seleccionar la pantalla correspondiente 
    CALL CALCULAR_CIFRAS_HEXA;
    CALL CALCULAR_CODIGOS_7SEG;
    
    MOVFW FSR;
    XORLW B'00000001'; alterno solamente el bit menos significativo del puntero
    MOVWF FSR;entonces puedo alternar de la dir 0x1A0 y 0x1A1 
    
    MOVFW INDF;
    MOVWF PORTB;cargo el valor de los pines de portb conectado a los segmentos de la pantalla
    
    ; Como solo el bit RD0 del port D selecciona la patalla que tiene que estar prendida en este momento
    ;puedo hacer toggle de ese bit y listo
    MOVFW PORTD;
    XORLW B'00000001';
    MOVWF PORTD;
    RETURN;
;MAIN---------------------------------------------------------------------------
MAIN
    CALL CONFIGS;
BUCLE
    GOTO BUCLE
    END