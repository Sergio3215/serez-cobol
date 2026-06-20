      *> Capstone: a small payroll batch combining tables, dec arithmetic,
      *> PERFORM VARYING, EVALUATE, IF, PIC editing and totals.
       IDENTIFICATION DIVISION.
       PROGRAM-ID. PAYBATCH.

       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-RATE       PIC 9(4)V99 OCCURS 3 TIMES.
       01 WS-HOURS      PIC 9(3)    OCCURS 3 TIMES.
       01 WS-I          PIC 9(3)    VALUE 0.
       01 WS-GROSS      PIC 9(7)V99 VALUE 0.
       01 WS-TAX        PIC 9(7)V99 VALUE 0.
       01 WS-NET        PIC 9(7)V99 VALUE 0.
       01 WS-TOTAL-NET  PIC 9(9)V99 VALUE 0.
       01 WS-BRACKET    PIC X(8)    VALUE "".
       01 WS-GROSS-ED   PIC ZZ,ZZ9.99 VALUE 0.
       01 WS-NET-ED     PIC $$,$$9.99 VALUE 0.
       01 WS-TOTAL-ED   PIC $$,$$$,$$9.99 VALUE 0.

       PROCEDURE DIVISION.
       MAIN-PARA.
           MOVE 25.00 TO WS-RATE(1).
           MOVE 160   TO WS-HOURS(1).
           MOVE 40.00 TO WS-RATE(2).
           MOVE 80    TO WS-HOURS(2).
           MOVE 15.50 TO WS-RATE(3).
           MOVE 170   TO WS-HOURS(3).
           PERFORM PAY-ONE VARYING WS-I FROM 1 BY 1 UNTIL WS-I > 3.
           MOVE WS-TOTAL-NET TO WS-TOTAL-ED.
           DISPLAY "----------------------------".
           DISPLAY "Total net: " WS-TOTAL-ED.
           STOP RUN.

       PAY-ONE.
           COMPUTE WS-GROSS = WS-RATE(WS-I) * WS-HOURS(WS-I).
           COMPUTE WS-TAX = WS-GROSS * 0.18 ROUNDED.
           COMPUTE WS-NET = WS-GROSS - WS-TAX.
           ADD WS-NET TO WS-TOTAL-NET.
           EVALUATE TRUE
               WHEN WS-GROSS > 5000 MOVE "HIGH" TO WS-BRACKET
               WHEN WS-GROSS > 2000 MOVE "MID" TO WS-BRACKET
               WHEN OTHER MOVE "LOW" TO WS-BRACKET
           END-EVALUATE.
           MOVE WS-GROSS TO WS-GROSS-ED.
           MOVE WS-NET TO WS-NET-ED.
           DISPLAY "Emp " WS-I ": gross " WS-GROSS-ED " net " WS-NET-ED " (" WS-BRACKET ")".
