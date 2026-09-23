CLASS zcl_exed_ptax_service DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    METHODS constructor
      IMPORTING source TYPE REF TO zif_exed_ptax_source
                calendar TYPE REF TO zif_exed_ptax_calendar
                store TYPE REF TO zif_exed_ptax_rate_store.
    METHODS run
      IMPORTING reference_date TYPE d
                quotation_date TYPE d OPTIONAL
                calendar_id TYPE zif_exed_ptax_types=>factory_calendar_code DEFAULT 'BR'
                simulate TYPE abap_bool DEFAULT abap_true
      RETURNING VALUE(result) TYPE zif_exed_ptax_types=>run_result
      RAISING zcx_exed_ptax.
    CLASS-METHODS pairs
      RETURNING VALUE(currency_pairs) TYPE zif_exed_ptax_types=>currency_pairs.
  PRIVATE SECTION.
    DATA source TYPE REF TO zif_exed_ptax_source.
    DATA calendar TYPE REF TO zif_exed_ptax_calendar.
    DATA store TYPE REF TO zif_exed_ptax_rate_store.
ENDCLASS.

CLASS zcl_exed_ptax_service IMPLEMENTATION.
  METHOD constructor.
    me->source = source.
    me->calendar = calendar.
    me->store = store.
  ENDMETHOD.

  METHOD pairs.
    currency_pairs = VALUE #(
      ( source_currency = 'BRL' target_currency = 'USD' bacen_currency = 'USD' quotation = 'I' )
      ( source_currency = 'USD' target_currency = 'BRL' bacen_currency = 'USD' quotation = 'D' )
      ( source_currency = 'BRL' target_currency = 'EUR' bacen_currency = 'EUR' quotation = 'I' )
      ( source_currency = 'EUR' target_currency = 'BRL' bacen_currency = 'EUR' quotation = 'D' )
      ( source_currency = 'GBP' target_currency = 'BRL' bacen_currency = 'GBP' quotation = 'D' )
      ( source_currency = 'CHF' target_currency = 'BRL' bacen_currency = 'CHF' quotation = 'D' )
      ( source_currency = 'AUD' target_currency = 'BRL' bacen_currency = 'AUD' quotation = 'D' ) ).
  ENDMETHOD.

  METHOD run.
    IF source IS NOT BOUND OR calendar IS NOT BOUND OR store IS NOT BOUND.
      RAISE EXCEPTION NEW zcx_exed_ptax( detail = 'Dependencias PTAX nao configuradas.' ).
    ENDIF.
    IF simulate <> abap_true AND simulate <> abap_false.
      RAISE EXCEPTION NEW zcx_exed_ptax( detail = 'Indicador de simulacao invalido.' ).
    ENDIF.
    result-simulation = simulate.
    IF quotation_date IS NOT INITIAL.
      result-quotation_date = quotation_date.
    ELSE.
      result-quotation_date = calendar->previous_workday(
        reference_date = reference_date calendar_id = calendar_id ).
    ENDIF.
    DATA quotation_timestamp TYPE timestamp.
    CONVERT DATE result-quotation_date TIME '000000'
      INTO TIME STAMP quotation_timestamp TIME ZONE 'UTC'.
    IF sy-subrc <> 0 OR result-quotation_date IS INITIAL.
      RAISE EXCEPTION NEW zcx_exed_ptax( detail = 'Data da cotacao invalida.' ).
    ENDIF.

    DATA(configured_pairs) = pairs( ).
    DATA currencies TYPE SORTED TABLE OF zif_exed_ptax_types=>bacen_currency_code
      WITH UNIQUE KEY table_line.
    LOOP AT configured_pairs INTO DATA(pair).
      INSERT pair-bacen_currency INTO TABLE currencies.
    ENDLOOP.

    " Concluir as consultas HTTP antes de iniciar a manutenção no SAP.
    LOOP AT currencies INTO DATA(currency).
      DATA(quote) = source->get_quote(
        currency = currency requested_date = result-quotation_date ).
      IF quote-currency <> currency
          OR quote-quotation_date <> result-quotation_date
          OR ( quote-found = abap_true AND quote-buy_rate <= 0 ).
        RAISE EXCEPTION NEW zcx_exed_ptax(
          detail = |Contrato de cotacao inconsistente: { currency }.| ).
      ENDIF.
      APPEND quote TO result-quotes.
    ENDLOOP.

    DATA eligible_pairs TYPE zif_exed_ptax_types=>currency_pairs.
    LOOP AT configured_pairs INTO pair.
      READ TABLE result-quotes INTO quote
        WITH KEY currency = pair-bacen_currency.
      IF quote-found = abap_true.
        APPEND pair TO eligible_pairs.
      ELSE.
        APPEND VALUE #(
          source_currency = pair-source_currency
          target_currency = pair-target_currency
          bacen_currency = pair-bacen_currency
          quotation = pair-quotation
          effective_date = result-quotation_date
          action = zif_exed_ptax_types=>action_no_bulletin
          message = 'Sem boletim nessa data; taxa existente preservada.' ) TO result-items.
      ENDIF.
    ENDLOOP.
    IF eligible_pairs IS NOT INITIAL.
      DATA(evaluated_items) = store->inspect(
        requested_date = result-quotation_date currency_pairs = eligible_pairs quotes = result-quotes ).
      IF simulate = abap_false.
        evaluated_items = store->apply( evaluated_items ).
      ENDIF.
      APPEND LINES OF evaluated_items TO result-items.
    ENDIF.
    SORT result-items BY source_currency target_currency.
  ENDMETHOD.
ENDCLASS.
