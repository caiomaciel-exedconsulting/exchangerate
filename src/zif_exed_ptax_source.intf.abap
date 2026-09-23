INTERFACE zif_exed_ptax_source PUBLIC.
  METHODS get_quote
    IMPORTING currency TYPE zif_exed_ptax_types=>bacen_currency_code
              requested_date TYPE d
    RETURNING VALUE(quote) TYPE zif_exed_ptax_types=>ptax_quote
    RAISING zcx_exed_ptax.
ENDINTERFACE.
