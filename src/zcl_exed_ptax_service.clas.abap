CLASS zcl_exed_ptax_service DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    METHODS constructor
      IMPORTING io_source TYPE REF TO zif_exed_ptax_source
                io_calendar TYPE REF TO zif_exed_ptax_calendar
                io_store TYPE REF TO zif_exed_ptax_rate_store.
    METHODS run
      IMPORTING iv_reference_date TYPE d
                iv_quotation_date TYPE d OPTIONAL
                iv_calendar_id TYPE zif_exed_ptax_types=>ty_calendar_id DEFAULT 'BR'
                iv_simulate TYPE abap_bool DEFAULT abap_true
      RETURNING VALUE(rs_result) TYPE zif_exed_ptax_types=>ty_result
      RAISING zcx_exed_ptax.
    CLASS-METHODS pairs
      RETURNING VALUE(rt_pairs) TYPE zif_exed_ptax_types=>tt_pairs.
  PRIVATE SECTION.
    DATA mo_source TYPE REF TO zif_exed_ptax_source.
    DATA mo_calendar TYPE REF TO zif_exed_ptax_calendar.
    DATA mo_store TYPE REF TO zif_exed_ptax_rate_store.
ENDCLASS.

CLASS zcl_exed_ptax_service IMPLEMENTATION.
  METHOD constructor.
    mo_source = io_source.
    mo_calendar = io_calendar.
    mo_store = io_store.
  ENDMETHOD.

  METHOD pairs.
    rt_pairs = VALUE #(
      ( source_currency = 'BRL' target_currency = 'USD' bacen_currency = 'USD' quotation = 'I' )
      ( source_currency = 'USD' target_currency = 'BRL' bacen_currency = 'USD' quotation = 'D' )
      ( source_currency = 'BRL' target_currency = 'EUR' bacen_currency = 'EUR' quotation = 'I' )
      ( source_currency = 'EUR' target_currency = 'BRL' bacen_currency = 'EUR' quotation = 'D' )
      ( source_currency = 'GBP' target_currency = 'BRL' bacen_currency = 'GBP' quotation = 'D' )
      ( source_currency = 'CHF' target_currency = 'BRL' bacen_currency = 'CHF' quotation = 'D' )
      ( source_currency = 'AUD' target_currency = 'BRL' bacen_currency = 'AUD' quotation = 'D' ) ).
  ENDMETHOD.

  METHOD run.
    IF mo_source IS NOT BOUND OR mo_calendar IS NOT BOUND OR mo_store IS NOT BOUND.
      RAISE EXCEPTION NEW zcx_exed_ptax( detail = 'Dependencias PTAX nao configuradas.' ).
    ENDIF.
    IF iv_simulate <> abap_true AND iv_simulate <> abap_false.
      RAISE EXCEPTION NEW zcx_exed_ptax( detail = 'Indicador de simulacao invalido.' ).
    ENDIF.
    rs_result-simulation = iv_simulate.
    IF iv_quotation_date IS NOT INITIAL.
      rs_result-quotation_date = iv_quotation_date.
    ELSE.
      rs_result-quotation_date = mo_calendar->previous_workday(
        iv_reference_date = iv_reference_date iv_calendar_id = iv_calendar_id ).
    ENDIF.
    DATA lv_stamp TYPE timestamp.
    CONVERT DATE rs_result-quotation_date TIME '000000'
      INTO TIME STAMP lv_stamp TIME ZONE 'UTC'.
    IF sy-subrc <> 0 OR rs_result-quotation_date IS INITIAL.
      RAISE EXCEPTION NEW zcx_exed_ptax( detail = 'Data da cotacao invalida.' ).
    ENDIF.

    DATA(lt_pairs) = pairs( ).
    DATA lt_currencies TYPE SORTED TABLE OF zif_exed_ptax_types=>ty_bacen_currency
      WITH UNIQUE KEY table_line.
    LOOP AT lt_pairs INTO DATA(ls_pair).
      INSERT ls_pair-bacen_currency INTO TABLE lt_currencies.
    ENDLOOP.

    " Concluir as consultas HTTP antes de iniciar a manutenção no SAP.
    LOOP AT lt_currencies INTO DATA(lv_currency).
      DATA(ls_quote) = mo_source->get_quote(
        iv_currency = lv_currency iv_date = rs_result-quotation_date ).
      IF ls_quote-currency <> lv_currency
          OR ls_quote-quotation_date <> rs_result-quotation_date
          OR ( ls_quote-found = abap_true AND ls_quote-buy_rate <= 0 ).
        RAISE EXCEPTION NEW zcx_exed_ptax(
          detail = |Contrato de cotacao inconsistente: { lv_currency }.| ).
      ENDIF.
      APPEND ls_quote TO rs_result-quotes.
    ENDLOOP.

    DATA lt_eligible TYPE zif_exed_ptax_types=>tt_pairs.
    LOOP AT lt_pairs INTO ls_pair.
      READ TABLE rs_result-quotes INTO ls_quote
        WITH KEY currency = ls_pair-bacen_currency.
      IF ls_quote-found = abap_true.
        APPEND ls_pair TO lt_eligible.
      ELSE.
        APPEND VALUE #(
          source_currency = ls_pair-source_currency
          target_currency = ls_pair-target_currency
          bacen_currency = ls_pair-bacen_currency
          quotation = ls_pair-quotation
          effective_date = rs_result-quotation_date
          action = zif_exed_ptax_types=>action_no_bulletin
          message = 'Sem boletim nessa data; taxa existente preservada.' ) TO rs_result-items.
      ENDIF.
    ENDLOOP.
    IF lt_eligible IS NOT INITIAL.
      DATA(lt_ready) = mo_store->inspect(
        iv_date = rs_result-quotation_date it_pairs = lt_eligible it_quotes = rs_result-quotes ).
      IF iv_simulate = abap_false.
        lt_ready = mo_store->apply( lt_ready ).
      ENDIF.
      APPEND LINES OF lt_ready TO rs_result-items.
    ENDIF.
    SORT rs_result-items BY source_currency target_currency.
  ENDMETHOD.
ENDCLASS.
