INTERFACE zif_exed_ptax_types PUBLIC.
  TYPES ty_currency TYPE c LENGTH 5.
  TYPES ty_bacen_currency TYPE c LENGTH 3.
  TYPES ty_calendar_id TYPE c LENGTH 2.
  TYPES ty_quotation TYPE c LENGTH 1.
  TYPES ty_rate TYPE i_currencyexchangeratetp_2-AbsoluteExchangeRate.
  TYPES:
    BEGIN OF ty_pair,
      source_currency TYPE ty_currency,
      target_currency TYPE ty_currency,
      bacen_currency TYPE ty_bacen_currency,
      quotation TYPE ty_quotation,
    END OF ty_pair,
    tt_pairs TYPE STANDARD TABLE OF ty_pair WITH EMPTY KEY,
    BEGIN OF ty_quote,
      currency TYPE ty_bacen_currency,
      quotation_date TYPE d,
      found TYPE abap_bool,
      buy_rate TYPE decfloat34,
      bulletin_timestamp TYPE string,
    END OF ty_quote,
    tt_quotes TYPE STANDARD TABLE OF ty_quote WITH EMPTY KEY,
    BEGIN OF ty_item,
      source_currency TYPE ty_currency,
      target_currency TYPE ty_currency,
      bacen_currency TYPE ty_bacen_currency,
      quotation TYPE ty_quotation,
      effective_date TYPE d,
      buy_rate TYPE decfloat34,
      absolute_rate TYPE ty_rate,
      old_signed_rate TYPE ty_rate,
      source_units TYPE decfloat34,
      target_units TYPE decfloat34,
      action TYPE c LENGTH 12,
      message TYPE string,
    END OF ty_item,
    tt_items TYPE STANDARD TABLE OF ty_item WITH EMPTY KEY,
    BEGIN OF ty_result,
      quotation_date TYPE d,
      simulation TYPE abap_bool,
      quotes TYPE tt_quotes,
      items TYPE tt_items,
    END OF ty_result.
  CONSTANTS exchange_rate_type TYPE c LENGTH 4 VALUE 'M'.
  CONSTANTS action_create TYPE c LENGTH 12 VALUE 'CREATE'.
  CONSTANTS action_update TYPE c LENGTH 12 VALUE 'UPDATE'.
  CONSTANTS action_unchanged TYPE c LENGTH 12 VALUE 'UNCHANGED'.
  CONSTANTS action_no_bulletin TYPE c LENGTH 12 VALUE 'NO_BULLETIN'.
  CONSTANTS action_error TYPE c LENGTH 12 VALUE 'ERROR'.
ENDINTERFACE.
