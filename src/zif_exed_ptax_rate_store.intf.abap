INTERFACE zif_exed_ptax_rate_store PUBLIC.
  METHODS inspect
    IMPORTING iv_date TYPE d
              it_pairs TYPE zif_exed_ptax_types=>tt_pairs
              it_quotes TYPE zif_exed_ptax_types=>tt_quotes
    RETURNING VALUE(rt_items) TYPE zif_exed_ptax_types=>tt_items
    RAISING zcx_exed_ptax.
  METHODS apply
    IMPORTING it_items TYPE zif_exed_ptax_types=>tt_items
    RETURNING VALUE(rt_items) TYPE zif_exed_ptax_types=>tt_items
    RAISING zcx_exed_ptax.
ENDINTERFACE.
