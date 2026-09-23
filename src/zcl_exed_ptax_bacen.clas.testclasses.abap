CLASS ltc_bacen DEFINITION DEFERRED.
CLASS zcl_exed_ptax_bacen DEFINITION LOCAL FRIENDS ltc_bacen.

CLASS ltc_bacen DEFINITION FINAL FOR TESTING DURATION SHORT RISK LEVEL HARMLESS.
  PRIVATE SECTION.
    DATA mo_cut TYPE REF TO zcl_exed_ptax_bacen.
    METHODS setup.
    METHODS query_currency_and_date FOR TESTING RAISING zcx_exed_ptax.
    METHODS reject_bad_requests FOR TESTING.
    METHODS map_purchase_quote FOR TESTING RAISING zcx_exed_ptax.
    METHODS no_bulletin_is_not_error FOR TESTING RAISING zcx_exed_ptax.
    METHODS reject_bad_json_contract FOR TESTING.
    METHODS reject_wrong_quote FOR TESTING.
    METHODS expect_rejected IMPORTING iv_json TYPE string.
ENDCLASS.

CLASS ltc_bacen IMPLEMENTATION.
  METHOD setup.
    mo_cut = NEW #( ).
  ENDMETHOD.

  METHOD query_currency_and_date.
    DATA(lv_query) = mo_cut->build_query( iv_currency = 'CHF' iv_date = '20240328' ).
    cl_abap_unit_assert=>assert_true( xsdbool( contains( val = lv_query
      sub = |@moeda='CHF'&@dataCotacao='03-28-2024'| ) ) ).
    cl_abap_unit_assert=>assert_true( xsdbool( contains( val = lv_query
      sub = |$filter=tipoBoletim%20eq%20'Fechamento%20PTAX'| ) ) ).
    cl_abap_unit_assert=>assert_true( xsdbool( contains( val = lv_query sub = '$format=json' ) ) ).
    DATA lt_currencies TYPE STANDARD TABLE OF zif_exed_ptax_types=>ty_bacen_currency WITH EMPTY KEY.
    lt_currencies = VALUE #( ( 'USD' ) ( 'EUR' ) ( 'GBP' ) ( 'CHF' ) ( 'AUD' ) ).
    LOOP AT lt_currencies INTO DATA(lv_currency).
      lv_query = mo_cut->build_query( iv_currency = lv_currency iv_date = '20240229' ).
      cl_abap_unit_assert=>assert_not_initial( lv_query ).
    ENDLOOP.
  ENDMETHOD.

  METHOD reject_bad_requests.
    TRY.
        mo_cut->build_query( iv_currency = 'BRL' iv_date = '20240328' ).
        cl_abap_unit_assert=>fail( 'BRL must never be submitted to BACEN' ).
      CATCH zcx_exed_ptax.
    ENDTRY.
    TRY.
        mo_cut->build_query( iv_currency = 'USD' iv_date = '20240230' ).
        cl_abap_unit_assert=>fail( 'Invalid calendar date must be rejected' ).
      CATCH zcx_exed_ptax.
    ENDTRY.
    TRY.
        mo_cut->build_query( iv_currency = 'USD' iv_date = '00000000' ).
        cl_abap_unit_assert=>fail( 'Initial date must be rejected' ).
      CATCH zcx_exed_ptax.
    ENDTRY.
  ENDMETHOD.

  METHOD map_purchase_quote.
    DATA(ls_quote) = mo_cut->parse_response(
      iv_currency = 'EUR' iv_date = '20240328'
      iv_json = `{"@odata.context":"fixture","value":[{"cotacaoCompra":5.39520,`
        && `"cotacaoVenda":5.39790,"dataHoraCotacao":"2024-03-28 14:40:02.052",`
        && `"tipoBoletim":"Fechamento PTAX"}]}` ).
    cl_abap_unit_assert=>assert_true( ls_quote-found ).
    cl_abap_unit_assert=>assert_equals( act = ls_quote-currency exp = 'EUR' ).
    cl_abap_unit_assert=>assert_equals( act = ls_quote-quotation_date exp = '20240328' ).
    cl_abap_unit_assert=>assert_equals( act = ls_quote-buy_rate exp = CONV decfloat34( '5.39520' ) ).
    cl_abap_unit_assert=>assert_equals( act = ls_quote-bulletin_timestamp exp = '2024-03-28 14:40:02.052' ).
  ENDMETHOD.

  METHOD no_bulletin_is_not_error.
    " Uma leitura anterior não deve deixar estado na próxima resposta.
    map_purchase_quote( ).
    DATA(ls_quote) = mo_cut->parse_response( iv_currency = 'USD' iv_date = '20240329'
      iv_json = `{"@odata.context":"fixture","value":[]}` ).
    cl_abap_unit_assert=>assert_false( ls_quote-found ).
    cl_abap_unit_assert=>assert_initial( ls_quote-buy_rate ).
    cl_abap_unit_assert=>assert_equals( act = ls_quote-quotation_date exp = '20240329' ).
  ENDMETHOD.

  METHOD reject_bad_json_contract.
    expect_rejected( `{` ).
    expect_rejected( `   ` ).
    expect_rejected( `null` ).
    expect_rejected( `[]` ).
    expect_rejected( `{"error":{"message":"Remote error"}}` ).
    expect_rejected( `{"nested":{"value":[]}}` ).
    expect_rejected( `{"value":null}` ).
    expect_rejected( `{"value":{}}` ).
    expect_rejected( `{"value":[1]}` ).
    expect_rejected( `{"value":[null]}` ).
    expect_rejected( `{"value":[{}]}` ).
    expect_rejected( `{"value":[{"cotacaoCompra":"4.99","dataHoraCotacao":"2024-03-28 14:40:02",`
      && `"tipoBoletim":"Fechamento PTAX"}]}` ).
    expect_rejected( `{"value":[{"cotacaoCompra":4.99,"dataHoraCotacao":null,`
      && `"tipoBoletim":"Fechamento PTAX"}]}` ).
  ENDMETHOD.

  METHOD reject_wrong_quote.
    expect_rejected( `{"value":[{"cotacaoCompra":0,"dataHoraCotacao":"2024-03-28 14:40:02",`
      && `"tipoBoletim":"Fechamento PTAX"}]}` ).
    expect_rejected( `{"value":[{"cotacaoCompra":-1,"dataHoraCotacao":"2024-03-28 14:40:02",`
      && `"tipoBoletim":"Fechamento PTAX"}]}` ).
    expect_rejected( `{"value":[{"cotacaoCompra":4.99,"dataHoraCotacao":"2024-03-27 14:40:02",`
      && `"tipoBoletim":"Fechamento PTAX"}]}` ).
    expect_rejected( `{"value":[{"cotacaoCompra":4.99,"dataHoraCotacao":"2024-03-28 14:40:02",`
      && `"tipoBoletim":"Fechamento"}]}` ).
    expect_rejected( `{"value":[{"cotacaoCompra":4.99,"dataHoraCotacao":"2024-03-28 14:40:02",`
      && `"tipoBoletim":"Fechamento PTAX"},{"cotacaoCompra":4.99,`
      && `"dataHoraCotacao":"2024-03-28 14:40:02","tipoBoletim":"Fechamento PTAX"}]}` ).
  ENDMETHOD.

  METHOD expect_rejected.
    TRY.
        mo_cut->parse_response( iv_currency = 'USD' iv_date = '20240328' iv_json = iv_json ).
        cl_abap_unit_assert=>fail( 'Invalid response must not be interpreted as absence/success' ).
      CATCH zcx_exed_ptax INTO DATA(lx_expected).
        cl_abap_unit_assert=>assert_not_initial( lx_expected->detail ).
    ENDTRY.
  ENDMETHOD.
ENDCLASS.
