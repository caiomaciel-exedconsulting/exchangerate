INTERFACE zif_exed_ptax_source PUBLIC.
  METHODS get_quote
    IMPORTING iv_currency TYPE zif_exed_ptax_types=>ty_bacen_currency
              iv_date TYPE d
    RETURNING VALUE(rs_quote) TYPE zif_exed_ptax_types=>ty_quote
    RAISING zcx_exed_ptax.
ENDINTERFACE.
