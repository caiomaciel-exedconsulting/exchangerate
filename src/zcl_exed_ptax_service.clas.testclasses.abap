CLASS lcl_source DEFINITION FINAL.
  PUBLIC SECTION.
    INTERFACES zif_exed_ptax_source.
    DATA absent TYPE zif_exed_ptax_types=>ty_bacen_currency.
    DATA all_absent TYPE abap_bool.
    DATA fail TYPE abap_bool.
    DATA calls TYPE i.
    DATA last_date TYPE d.
ENDCLASS.
CLASS lcl_source IMPLEMENTATION.
  METHOD zif_exed_ptax_source~get_quote.
    calls += 1.
    last_date = iv_date.
    IF fail = abap_true.
      RAISE EXCEPTION NEW zcx_exed_ptax( detail = 'HTTP 503' ).
    ENDIF.
    rs_quote = VALUE #( currency = iv_currency quotation_date = iv_date
      found = xsdbool( all_absent = abap_false AND absent <> iv_currency )
      buy_rate = '4.99560' bulletin_timestamp = '2024-03-28 14:40:02.052' ).
  ENDMETHOD.
ENDCLASS.
CLASS lcl_calendar DEFINITION FINAL.
  PUBLIC SECTION.
    INTERFACES zif_exed_ptax_calendar.
    DATA calls TYPE i.
ENDCLASS.
CLASS lcl_calendar IMPLEMENTATION.
  METHOD zif_exed_ptax_calendar~previous_workday.
    calls += 1.
    rv_date = '20240328'.
  ENDMETHOD.
ENDCLASS.
CLASS lcl_store DEFINITION FINAL.
  PUBLIC SECTION.
    INTERFACES zif_exed_ptax_rate_store.
    DATA inspected TYPE zif_exed_ptax_types=>tt_pairs.
    DATA applied TYPE zif_exed_ptax_types=>tt_items.
    DATA inspect_calls TYPE i.
    DATA apply_calls TYPE i.
    DATA fail_currency TYPE zif_exed_ptax_types=>ty_bacen_currency.
ENDCLASS.
CLASS lcl_store IMPLEMENTATION.
  METHOD zif_exed_ptax_rate_store~inspect.
    inspect_calls += 1.
    inspected = it_pairs.
    LOOP AT it_pairs INTO DATA(pair).
      APPEND VALUE #( source_currency = pair-source_currency
        target_currency = pair-target_currency bacen_currency = pair-bacen_currency
        quotation = pair-quotation effective_date = iv_date
        action = zif_exed_ptax_types=>action_create ) TO rt_items.
    ENDLOOP.
  ENDMETHOD.
  METHOD zif_exed_ptax_rate_store~apply.
    apply_calls += 1.
    applied = it_items.
    rt_items = it_items.
    LOOP AT rt_items ASSIGNING FIELD-SYMBOL(<item>) WHERE bacen_currency = fail_currency.
      <item>-action = zif_exed_ptax_types=>action_error.
      <item>-message = 'Falha simulada deste par; demais preservados.'.
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.

CLASS ltcl_service DEFINITION FINAL FOR TESTING DURATION SHORT RISK LEVEL HARMLESS.
  PRIVATE SECTION.
    DATA source TYPE REF TO lcl_source.
    DATA calendar TYPE REF TO lcl_calendar.
    DATA store TYPE REF TO lcl_store.
    DATA service TYPE REF TO zcl_exed_ptax_service.
    METHODS setup.
    METHODS missing_usd FOR TESTING RAISING zcx_exed_ptax.
    METHODS missing_aud FOR TESTING RAISING zcx_exed_ptax.
    METHODS all_missing FOR TESTING RAISING zcx_exed_ptax.
    METHODS simulation_never_writes FOR TESTING RAISING zcx_exed_ptax.
    METHODS explicit_date FOR TESTING RAISING zcx_exed_ptax.
    METHODS http_failure_never_writes FOR TESTING.
    METHODS partial_failure_retained FOR TESTING RAISING zcx_exed_ptax.
ENDCLASS.
CLASS ltcl_service IMPLEMENTATION.
  METHOD setup.
    source = NEW #( ).
    calendar = NEW #( ).
    store = NEW #( ).
    service = NEW #( io_source = source io_calendar = calendar io_store = store ).
  ENDMETHOD.
  METHOD missing_usd.
    source->absent = 'USD'.
    DATA(result) = service->run( iv_reference_date = '20240401' iv_simulate = abap_false ).
    cl_abap_unit_assert=>assert_equals( act = source->calls exp = 5 ).
    cl_abap_unit_assert=>assert_equals( act = lines( store->applied ) exp = 5 ).
    cl_abap_unit_assert=>assert_equals( act = lines( result-items ) exp = 7 ).
    cl_abap_unit_assert=>assert_false( xsdbool( line_exists( store->inspected[ bacen_currency = 'USD' ] ) ) ).
    cl_abap_unit_assert=>assert_equals(
      act = result-items[ source_currency = 'BRL' target_currency = 'USD' ]-action
      exp = zif_exed_ptax_types=>action_no_bulletin ).
    cl_abap_unit_assert=>assert_equals(
      act = result-items[ source_currency = 'USD' target_currency = 'BRL' ]-action
      exp = zif_exed_ptax_types=>action_no_bulletin ).
  ENDMETHOD.
  METHOD missing_aud.
    source->absent = 'AUD'.
    DATA(result) = service->run( iv_reference_date = '20240401' iv_simulate = abap_false ).
    cl_abap_unit_assert=>assert_equals( act = lines( store->applied ) exp = 6 ).
    cl_abap_unit_assert=>assert_equals(
      act = result-items[ source_currency = 'AUD' target_currency = 'BRL' ]-action
      exp = zif_exed_ptax_types=>action_no_bulletin ).
  ENDMETHOD.
  METHOD all_missing.
    source->all_absent = abap_true.
    DATA(result) = service->run( iv_reference_date = '20240401' iv_simulate = abap_false ).
    cl_abap_unit_assert=>assert_equals( act = lines( result-items ) exp = 7 ).
    cl_abap_unit_assert=>assert_equals( act = store->inspect_calls exp = 0 ).
    cl_abap_unit_assert=>assert_equals( act = store->apply_calls exp = 0 ).
    cl_abap_unit_assert=>assert_equals( act = source->calls exp = 5 ).
  ENDMETHOD.
  METHOD simulation_never_writes.
    DATA(result) = service->run( iv_reference_date = '20240401' ).
    cl_abap_unit_assert=>assert_equals( act = store->inspect_calls exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = store->apply_calls exp = 0 ).
    cl_abap_unit_assert=>assert_true( result-simulation ).
  ENDMETHOD.
  METHOD explicit_date.
    DATA(result) = service->run( iv_reference_date = '20240401' iv_quotation_date = '20240327' ).
    cl_abap_unit_assert=>assert_equals( act = calendar->calls exp = 0 ).
    cl_abap_unit_assert=>assert_equals( act = source->last_date exp = '20240327' ).
    cl_abap_unit_assert=>assert_equals( act = result-quotation_date exp = '20240327' ).
  ENDMETHOD.
  METHOD http_failure_never_writes.
    source->fail = abap_true.
    TRY.
        service->run( iv_reference_date = '20240401' iv_simulate = abap_false ).
        cl_abap_unit_assert=>fail( 'Falha HTTP deveria interromper a manutencao.' ).
      CATCH zcx_exed_ptax.
        cl_abap_unit_assert=>assert_equals( act = store->inspect_calls exp = 0 ).
        cl_abap_unit_assert=>assert_equals( act = store->apply_calls exp = 0 ).
    ENDTRY.
  ENDMETHOD.
  METHOD partial_failure_retained.
    store->fail_currency = 'AUD'.
    DATA(result) = service->run( iv_reference_date = '20240401' iv_simulate = abap_false ).
    cl_abap_unit_assert=>assert_equals( act = lines( result-items ) exp = 7 ).
    cl_abap_unit_assert=>assert_equals(
      act = result-items[ source_currency = 'AUD' target_currency = 'BRL' ]-action
      exp = zif_exed_ptax_types=>action_error ).
    cl_abap_unit_assert=>assert_equals(
      act = result-items[ source_currency = 'USD' target_currency = 'BRL' ]-action
      exp = zif_exed_ptax_types=>action_create ).
  ENDMETHOD.
ENDCLASS.
