INTERFACE zif_exed_ptax_rate_store PUBLIC.
  METHODS inspect
    IMPORTING requested_date TYPE d
              currency_pairs TYPE zif_exed_ptax_types=>currency_pairs
              quotes TYPE zif_exed_ptax_types=>ptax_quotes
    RETURNING VALUE(result_items) TYPE zif_exed_ptax_types=>rate_items
    RAISING zcx_exed_ptax.
  METHODS apply
    IMPORTING items TYPE zif_exed_ptax_types=>rate_items
    RETURNING VALUE(result_items) TYPE zif_exed_ptax_types=>rate_items
    RAISING zcx_exed_ptax.
ENDINTERFACE.
