CLASS zcx_exed_ptax DEFINITION PUBLIC INHERITING FROM cx_static_check
  FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    DATA detail TYPE string READ-ONLY.
    METHODS constructor
      IMPORTING detail TYPE string previous TYPE REF TO cx_root OPTIONAL.
    METHODS if_message~get_text REDEFINITION.
ENDCLASS.

CLASS zcx_exed_ptax IMPLEMENTATION.
  METHOD constructor.
    super->constructor( previous = previous ).
    me->detail = detail.
  ENDMETHOD.
  METHOD if_message~get_text.
    result = detail.
  ENDMETHOD.
ENDCLASS.
