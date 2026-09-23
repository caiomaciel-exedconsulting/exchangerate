INTERFACE zif_exed_ptax_types PUBLIC.
  TYPES currency_code TYPE c LENGTH 5.
  TYPES bacen_currency_code TYPE c LENGTH 3.
  TYPES factory_calendar_code TYPE c LENGTH 2.
  TYPES quotation_notation TYPE c LENGTH 1.
  TYPES exchange_rate TYPE i_currencyexchangeratetp_2-AbsoluteExchangeRate.
  TYPES:
    BEGIN OF currency_pair,
      source_currency TYPE currency_code,
      target_currency TYPE currency_code,
      bacen_currency TYPE bacen_currency_code,
      quotation TYPE quotation_notation,
    END OF currency_pair,
    currency_pairs TYPE STANDARD TABLE OF currency_pair WITH EMPTY KEY,
    BEGIN OF ptax_quote,
      currency TYPE bacen_currency_code,
      quotation_date TYPE d,
      found TYPE abap_bool,
      buy_rate TYPE decfloat34,
      bulletin_timestamp TYPE string,
    END OF ptax_quote,
    ptax_quotes TYPE STANDARD TABLE OF ptax_quote WITH EMPTY KEY,
    BEGIN OF rate_item,
      source_currency TYPE currency_code,
      target_currency TYPE currency_code,
      bacen_currency TYPE bacen_currency_code,
      quotation TYPE quotation_notation,
      effective_date TYPE d,
      buy_rate TYPE decfloat34,
      absolute_rate TYPE exchange_rate,
      old_signed_rate TYPE exchange_rate,
      source_units TYPE decfloat34,
      target_units TYPE decfloat34,
      action TYPE c LENGTH 12,
      message TYPE string,
    END OF rate_item,
    rate_items TYPE STANDARD TABLE OF rate_item WITH EMPTY KEY,
    BEGIN OF run_result,
      quotation_date TYPE d,
      simulation TYPE abap_bool,
      quotes TYPE ptax_quotes,
      items TYPE rate_items,
    END OF run_result.
  CONSTANTS exchange_rate_type TYPE c LENGTH 4 VALUE 'M'.
  CONSTANTS action_create TYPE c LENGTH 12 VALUE 'CREATE'.
  CONSTANTS action_update TYPE c LENGTH 12 VALUE 'UPDATE'.
  CONSTANTS action_unchanged TYPE c LENGTH 12 VALUE 'UNCHANGED'.
  CONSTANTS action_no_bulletin TYPE c LENGTH 12 VALUE 'NO_BULLETIN'.
  CONSTANTS action_error TYPE c LENGTH 12 VALUE 'ERROR'.
ENDINTERFACE.
