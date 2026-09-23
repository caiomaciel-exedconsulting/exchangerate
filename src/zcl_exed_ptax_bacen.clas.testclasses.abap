CLASS bacen_tests DEFINITION DEFERRED.
CLASS zcl_exed_ptax_bacen DEFINITION LOCAL FRIENDS bacen_tests.

CLASS bacen_tests DEFINITION FINAL FOR TESTING DURATION SHORT RISK LEVEL HARMLESS.
  PRIVATE SECTION.
    DATA bacen TYPE REF TO zcl_exed_ptax_bacen.
    METHODS setup.
    METHODS query_currency_and_date FOR TESTING RAISING zcx_exed_ptax.
    METHODS reject_bad_requests FOR TESTING.
    METHODS map_purchase_quote FOR TESTING RAISING zcx_exed_ptax.
    METHODS no_bulletin_is_not_error FOR TESTING RAISING zcx_exed_ptax.
    METHODS reject_bad_json_contract FOR TESTING.
    METHODS reject_wrong_quote FOR TESTING.
    METHODS expect_rejected IMPORTING json_text TYPE string.
ENDCLASS.

CLASS bacen_tests IMPLEMENTATION.
  METHOD setup.
    bacen = NEW #( ).
  ENDMETHOD.

  METHOD query_currency_and_date.
    DATA(query) = bacen->build_query( currency = 'CHF' requested_date = '20240328' ).
    cl_abap_unit_assert=>assert_true( xsdbool( contains( val = query
      sub = |@moeda='CHF'&@dataCotacao='03-28-2024'| ) ) ).
    cl_abap_unit_assert=>assert_true( xsdbool( contains( val = query
      sub = |$filter=tipoBoletim%20eq%20'Fechamento%20PTAX'| ) ) ).
    cl_abap_unit_assert=>assert_true( xsdbool( contains( val = query sub = '$format=json' ) ) ).
    DATA currencies TYPE STANDARD TABLE OF zif_exed_ptax_types=>bacen_currency_code WITH EMPTY KEY.
    currencies = VALUE #( ( 'USD' ) ( 'EUR' ) ( 'GBP' ) ( 'CHF' ) ( 'AUD' ) ).
    LOOP AT currencies INTO DATA(currency).
      query = bacen->build_query( currency = currency requested_date = '20240229' ).
      cl_abap_unit_assert=>assert_not_initial( query ).
    ENDLOOP.
  ENDMETHOD.

  METHOD reject_bad_requests.
    TRY.
        bacen->build_query( currency = 'BRL' requested_date = '20240328' ).
        cl_abap_unit_assert=>fail( 'BRL must never be submitted to BACEN' ).
      CATCH zcx_exed_ptax.
    ENDTRY.
    TRY.
        bacen->build_query( currency = 'USD' requested_date = '20240230' ).
        cl_abap_unit_assert=>fail( 'Invalid calendar date must be rejected' ).
      CATCH zcx_exed_ptax.
    ENDTRY.
    TRY.
        bacen->build_query( currency = 'USD' requested_date = '00000000' ).
        cl_abap_unit_assert=>fail( 'Initial date must be rejected' ).
      CATCH zcx_exed_ptax.
    ENDTRY.
  ENDMETHOD.

  METHOD map_purchase_quote.
    DATA(quote) = bacen->parse_response(
      currency = 'EUR' requested_date = '20240328'
      json_text = `{"@odata.context":"fixture","value":[{"cotacaoCompra":5.39520,`
        && `"cotacaoVenda":5.39790,"dataHoraCotacao":"2024-03-28 14:40:02.052",`
        && `"tipoBoletim":"Fechamento PTAX"}]}` ).
    cl_abap_unit_assert=>assert_true( quote-found ).
    cl_abap_unit_assert=>assert_equals( act = quote-currency exp = 'EUR' ).
    cl_abap_unit_assert=>assert_equals( act = quote-quotation_date exp = '20240328' ).
    cl_abap_unit_assert=>assert_equals( act = quote-buy_rate exp = CONV decfloat34( '5.39520' ) ).
    cl_abap_unit_assert=>assert_equals( act = quote-bulletin_timestamp exp = '2024-03-28 14:40:02.052' ).
  ENDMETHOD.

  METHOD no_bulletin_is_not_error.
    " Uma leitura anterior não deve deixar estado na próxima resposta.
    map_purchase_quote( ).
    DATA(quote) = bacen->parse_response( currency = 'USD' requested_date = '20240329'
      json_text = `{"@odata.context":"fixture","value":[]}` ).
    cl_abap_unit_assert=>assert_false( quote-found ).
    cl_abap_unit_assert=>assert_initial( quote-buy_rate ).
    cl_abap_unit_assert=>assert_equals( act = quote-quotation_date exp = '20240329' ).
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
        bacen->parse_response( currency = 'USD' requested_date = '20240328' json_text = json_text ).
        cl_abap_unit_assert=>fail( 'Invalid response must not be interpreted as absence/success' ).
      CATCH zcx_exed_ptax INTO DATA(expected_error).
        cl_abap_unit_assert=>assert_not_initial( expected_error->detail ).
    ENDTRY.
  ENDMETHOD.
ENDCLASS.
