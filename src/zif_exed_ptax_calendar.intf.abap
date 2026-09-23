INTERFACE zif_exed_ptax_calendar PUBLIC.
  METHODS previous_workday
    IMPORTING reference_date TYPE d
              calendar_id TYPE zif_exed_ptax_types=>factory_calendar_code
    RETURNING VALUE(workday) TYPE d
    RAISING zcx_exed_ptax.
ENDINTERFACE.
