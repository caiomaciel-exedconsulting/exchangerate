INTERFACE zif_exed_ptax_calendar PUBLIC.
  METHODS previous_workday
    IMPORTING iv_reference_date TYPE d
              iv_calendar_id TYPE zif_exed_ptax_types=>ty_calendar_id
    RETURNING VALUE(rv_date) TYPE d
    RAISING zcx_exed_ptax.
ENDINTERFACE.
