      *> Integration: write a file, read it back, total with exact dec,
      *> format with a numeric-edited PIC, classify with an EVALUATE range.
       IDENTIFICATION DIVISION.
       PROGRAM-ID. BATCH.
       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT OUT-FILE ASSIGN TO "batch.dat"
               ORGANIZATION IS LINE SEQUENTIAL.
           SELECT IN-FILE ASSIGN TO "batch.dat"
               ORGANIZATION IS LINE SEQUENTIAL.
       DATA DIVISION.
       FILE SECTION.
       FD OUT-FILE.
       01 OUT-REC PIC X(40).
       FD IN-FILE.
       01 IN-REC PIC X(40).
       WORKING-STORAGE SECTION.
       01 WS-PRICE  PIC 9(4)V99 OCCURS 4 TIMES.
       01 WS-QTY    PIC 9(3)    OCCURS 4 TIMES.
       01 WS-I      PIC 9(3)    VALUE 0.
       01 WS-LINE   PIC X(40)   VALUE "".
       01 WS-TOTAL  PIC 9(7)V99 VALUE 0.
       01 WS-TOT-ED PIC $$,$$9.99 VALUE 0.
       01 WS-EOF    PIC X VALUE "N".
          88 AT-EOF VALUE "Y".
       01 WS-CNT    PIC 9(3)    VALUE 0.

       PROCEDURE DIVISION.
       MAIN.
           MOVE 100.00  TO WS-PRICE(1). MOVE 2  TO WS-QTY(1).
           MOVE 50.50   TO WS-PRICE(2). MOVE 3  TO WS-QTY(2).
           MOVE 9.99    TO WS-PRICE(3). MOVE 10 TO WS-QTY(3).
           MOVE 1000.00 TO WS-PRICE(4). MOVE 1  TO WS-QTY(4).
           OPEN OUTPUT OUT-FILE.
           PERFORM WRITE-LINE VARYING WS-I FROM 1 BY 1 UNTIL WS-I > 4.
           CLOSE OUT-FILE.
           OPEN INPUT IN-FILE.
           PERFORM READ-LOOP UNTIL AT-EOF.
           CLOSE IN-FILE.
           MOVE WS-TOTAL TO WS-TOT-ED.
           DISPLAY "lines=" WS-CNT " total=" WS-TOT-ED.
           EVALUATE WS-TOTAL
               WHEN 0 THRU 99999 DISPLAY "tier=low"
               WHEN OTHER DISPLAY "tier=high"
           END-EVALUATE.
           STOP RUN.

       WRITE-LINE.
           COMPUTE WS-TOTAL = WS-TOTAL + WS-PRICE(WS-I) * WS-QTY(WS-I).
           STRING "item " WS-I DELIMITED BY SIZE INTO WS-LINE.
           WRITE OUT-REC FROM WS-LINE.

       READ-LOOP.
           READ IN-FILE
               AT END SET AT-EOF TO TRUE
               NOT AT END ADD 1 TO WS-CNT
           END-READ.
