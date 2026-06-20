      *> Showcase of v2.0 control-flow / arithmetic / condition features.
       IDENTIFICATION DIVISION.
       PROGRAM-ID. FEATURES.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       77 WS-CTR    PIC 9(3)    VALUE 0.
       77 WS-TICKS  PIC 9(3)    VALUE 0.
       01 WS-A      PIC 9(3)    VALUE 0.
       01 WS-B      PIC 9(3)    VALUE 0.
       01 WS-Q      PIC 9(5)    VALUE 0.
       01 WS-R      PIC 9(5)    VALUE 0.
       01 WS-POW    PIC 9(6)    VALUE 0.
       01 WS-D      PIC 9(3)V99 VALUE 0.
       01 WS-GRID   PIC 9(3)    OCCURS 9 TIMES.
       01 WS-I      PIC 9(3)    VALUE 0.
       01 WS-J      PIC 9(3)    VALUE 0.
       01 WS-CODE   PIC 9       VALUE 2.
       01 WS-G      PIC 9(3)    VALUE 75.
       01 WS-TXT    PIC X(5)    VALUE "12345".
       01 WS-FLAG   PIC X       VALUE "N".
          88 IS-READY VALUE "Y".

       PROCEDURE DIVISION.
       MAIN.
      *> multi-target MOVE / ADD / COMPUTE
           MOVE 7 TO WS-A WS-B.
           ADD 1 TO WS-A WS-B.
           COMPUTE WS-A WS-B = WS-A + WS-B.
           DISPLAY "a=" WS-A " b=" WS-B.
      *> DIVIDE with REMAINDER, exponentiation
           DIVIDE 17 BY 5 GIVING WS-Q REMAINDER WS-R.
           COMPUTE WS-POW = 3 ** 3.
           DISPLAY "q=" WS-Q " r=" WS-R " pow=" WS-POW.
      *> PERFORM <var> TIMES
           MOVE 4 TO WS-CTR.
           PERFORM TICK WS-CTR TIMES.
           DISPLAY "ticks=" WS-TICKS.
      *> nested PERFORM VARYING ... AFTER, dec step
           PERFORM VARYING WS-I FROM 1 BY 1 UNTIL WS-I > 3
               AFTER WS-J FROM 1 BY 1 UNTIL WS-J > 3
               COMPUTE WS-GRID((WS-I - 1) * 3 + WS-J) = WS-I * WS-J
           END-PERFORM.
           DISPLAY "g5=" WS-GRID(5) " g9=" WS-GRID(9).
      *> EVALUATE with OR-list and THRU range
           EVALUATE WS-CODE
               WHEN 1 WHEN 3 DISPLAY "odd"
               WHEN 2 DISPLAY "two"
               WHEN OTHER DISPLAY "other"
           END-EVALUATE.
           EVALUATE WS-G
               WHEN 90 THRU 100 DISPLAY "A"
               WHEN 70 THRU 89 DISPLAY "BC"
               WHEN OTHER DISPLAY "F"
           END-EVALUATE.
      *> implied-subject and class conditions, SET 88
           IF WS-CODE = 1 OR 2 OR 3 THEN
               DISPLAY "in set"
           END-IF.
           IF WS-TXT IS NUMERIC THEN
               DISPLAY "numeric"
           END-IF.
           SET IS-READY TO TRUE.
           IF IS-READY THEN
               DISPLAY "ready"
           END-IF.
           IF WS-A NOT > 1000 THEN
               DISPLAY "bounded"
           END-IF.
           GOBACK.

       TICK.
           ADD 1 TO WS-TICKS.
