CLASS zcx_exed_ptax DEFINITION   PUBLIC
  INHERITING FROM cx_static_check
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    INTERFACES if_t100_message .
    INTERFACES if_t100_dyn_msg .

    DATA detail TYPE msgv1.

    METHODS constructor
      IMPORTING
        !textid   LIKE if_t100_message=>t100key OPTIONAL
        !previous LIKE previous OPTIONAL
        !detail   TYPE msgv1 OPTIONAL.
  PROTECTED SECTION.
ENDCLASS.

CLASS zcx_exed_ptax IMPLEMENTATION.
  METHOD constructor ##ADT_SUPPRESS_GENERATION.
    super->constructor(
    previous = previous
    ).
    CLEAR me->textid.
    IF textid IS INITIAL.
      if_t100_message~t100key = if_t100_message=>default_textid.
    ELSE.
      if_t100_message~t100key = textid.
    ENDIF.
    IF detail IS NOT INITIAL.
      if_t100_message~t100key-attr1 = me->detail = detail.
    ENDIF.
  ENDMETHOD.
ENDCLASS.
