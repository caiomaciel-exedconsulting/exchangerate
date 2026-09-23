CLASS rate_store_tests DEFINITION DEFERRED.
CLASS zcl_exed_ptax_rate_store DEFINITION LOCAL FRIENDS rate_store_tests.

CLASS rate_store_tests DEFINITION FINAL FOR TESTING
  DURATION SHORT RISK LEVEL HARMLESS.
  PRIVATE SECTION.
    METHODS direct_nonunit_factors FOR TESTING RAISING zcx_exed_ptax.
    METHODS indirect_nonunit_factors FOR TESTING RAISING zcx_exed_ptax.
    METHODS sap_precision FOR TESTING RAISING zcx_exed_ptax.
    METHODS indirect_signed_comparison FOR TESTING RAISING zcx_exed_ptax.
    METHODS invalid_factor FOR TESTING.
    METHODS zero_after_rounding FOR TESTING.
    METHODS overflow FOR TESTING.
    METHODS invalid_notation FOR TESTING.
    METHODS activate_new_draft_pid FOR TESTING RAISING zcx_exed_ptax.
    METHODS activate_existing_key FOR TESTING RAISING zcx_exed_ptax.
    METHODS activate_pid_and_key FOR TESTING RAISING zcx_exed_ptax.
    METHODS reject_empty_activation FOR TESTING.
    METHODS reject_multiple_activation FOR TESTING.
    METHODS failed_without_reported FOR TESTING.
    METHODS empty_response_is_success FOR TESTING RAISING zcx_exed_ptax.
ENDCLASS.

CLASS rate_store_tests IMPLEMENTATION.
  METHOD direct_nonunit_factors.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_exed_ptax_rate_store=>normalize(
        buy_rate = '5.1234' quotation = 'D'
        factors = VALUE #( source_units = 100 target_units = 1 ) )
      exp = CONV zif_exed_ptax_types=>exchange_rate( '512.34' ) ).
  ENDMETHOD.

  METHOD indirect_nonunit_factors.
    "A cotação indireta preserva o valor BACEN, sem calcular seu inverso.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_exed_ptax_rate_store=>normalize(
        buy_rate = '5.1234' quotation = 'I'
        factors = VALUE #( source_units = 1 target_units = 100 ) )
      exp = CONV zif_exed_ptax_types=>exchange_rate( '512.34' ) ).
  ENDMETHOD.

  METHOD sap_precision.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_exed_ptax_rate_store=>normalize(
        buy_rate = '5.123456' quotation = 'D'
        factors = VALUE #( source_units = 1 target_units = 1 ) )
      exp = CONV zif_exed_ptax_types=>exchange_rate( '5.12346' ) ).
  ENDMETHOD.

  METHOD indirect_signed_comparison.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_exed_ptax_rate_store=>signed_rate(
        absolute_rate = CONV #( '5.1234' ) quotation = 'I' )
      exp = CONV zif_exed_ptax_types=>exchange_rate( '-5.1234' ) ).
  ENDMETHOD.

  METHOD invalid_factor.
    TRY.
        DATA(rate) = zcl_exed_ptax_rate_store=>normalize(
          buy_rate = 5 quotation = 'D'
          factors = VALUE #( source_units = 1 target_units = 0 ) ).
        cl_abap_unit_assert=>fail( 'Zero factor must fail.' ).
      CATCH zcx_exed_ptax.
    ENDTRY.
  ENDMETHOD.

  METHOD zero_after_rounding.
    TRY.
        DATA(rate) = zcl_exed_ptax_rate_store=>normalize(
          buy_rate = '0.00000001' quotation = 'D'
          factors = VALUE #( source_units = 1 target_units = 1 ) ).
        cl_abap_unit_assert=>fail( 'Unrepresentable positive rate must fail.' ).
      CATCH zcx_exed_ptax.
    ENDTRY.
  ENDMETHOD.

  METHOD overflow.
    TRY.
        DATA(rate) = zcl_exed_ptax_rate_store=>normalize(
          buy_rate = '1E30' quotation = 'D'
          factors = VALUE #( source_units = 100 target_units = 1 ) ).
        cl_abap_unit_assert=>fail( 'Overflow must fail.' ).
      CATCH zcx_exed_ptax.
    ENDTRY.
  ENDMETHOD.

  METHOD invalid_notation.
    TRY.
        DATA(rate) = zcl_exed_ptax_rate_store=>normalize(
          buy_rate = 5 quotation = 'X'
          factors = VALUE #( source_units = 1 target_units = 1 ) ).
        cl_abap_unit_assert=>fail( 'Invalid quotation must fail.' ).
      CATCH zcx_exed_ptax.
    ENDTRY.
  ENDMETHOD.

  METHOD activate_new_draft_pid.
    "Um novo rascunho pode ter apenas PID, sem chave definitiva.
    DATA keys TYPE zcl_exed_ptax_rate_store=>rate_keys.
    keys = VALUE #( ( %pid = '00112233445566778899AABBCCDDEEFF'
                     %is_draft = if_abap_behv=>mk-on ) ).
    DATA(requests) = zcl_exed_ptax_rate_store=>build_activation_requests( keys ).
    cl_abap_unit_assert=>assert_equals( act = lines( requests ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals(
      act = requests[ 1 ]-%pid exp = keys[ 1 ]-%pid
      msg = 'Activate deve preservar o PID do novo rascunho.' ).
    cl_abap_unit_assert=>assert_initial( requests[ 1 ]-%key ).
    cl_abap_unit_assert=>assert_not_initial( requests[ 1 ]-%cid ).
  ENDMETHOD.

  METHOD activate_existing_key.
    "Na edicao, a chave persistente identifica o registro existente.
    DATA keys TYPE zcl_exed_ptax_rate_store=>rate_keys.
    keys = VALUE #( ( ExchangeRateType = 'M' SourceCurrency = 'USD'
                     TargetCurrency = 'BRL' ExchangeRateEffectiveDate = '20260922'
                     %is_draft = if_abap_behv=>mk-on ) ).
    DATA(requests) = zcl_exed_ptax_rate_store=>build_activation_requests( keys ).
    cl_abap_unit_assert=>assert_equals(
      act = requests[ 1 ]-%key exp = keys[ 1 ]-%key
      msg = 'Activate deve preservar a chave completa do rascunho de edicao.' ).
    cl_abap_unit_assert=>assert_initial( requests[ 1 ]-%pid ).
  ENDMETHOD.

  METHOD activate_pid_and_key.
    "A identidade preliminar pode combinar PID e campos da chave.
    DATA keys TYPE zcl_exed_ptax_rate_store=>rate_keys.
    keys = VALUE #( ( %pid = 'FFEEDDCCBBAA99887766554433221100'
                     ExchangeRateType = 'M' SourceCurrency = 'BRL'
                     TargetCurrency = 'EUR' ExchangeRateEffectiveDate = '20260922'
                     %is_draft = if_abap_behv=>mk-on ) ).
    DATA(requests) = zcl_exed_ptax_rate_store=>build_activation_requests( keys ).
    cl_abap_unit_assert=>assert_equals(
      act = requests[ 1 ]-%pky exp = keys[ 1 ]-%pky
      msg = 'Activate deve preservar PID e chave quando ambos estiverem preenchidos.' ).
  ENDMETHOD.

  METHOD reject_empty_activation.
    TRY.
        DATA(requests) = zcl_exed_ptax_rate_store=>build_activation_requests( VALUE #( ) ).
        cl_abap_unit_assert=>fail( 'A ativacao sem identidade de rascunho deve falhar.' ).
      CATCH zcx_exed_ptax INTO DATA(error).
        cl_abap_unit_assert=>assert_equals(
          act = error->detail exp = 'Ativacao exige exatamente um rascunho.' ).
    ENDTRY.
  ENDMETHOD.

  METHOD reject_multiple_activation.
    DATA keys TYPE zcl_exed_ptax_rate_store=>rate_keys.
    keys = VALUE #( ( %pid = '00112233445566778899AABBCCDDEEFF' )
                   ( %pid = 'FFEEDDCCBBAA99887766554433221100' ) ).
    TRY.
        DATA(requests) = zcl_exed_ptax_rate_store=>build_activation_requests( keys ).
        cl_abap_unit_assert=>fail( 'A ativacao de varios pares na mesma LUW deve falhar.' ).
      CATCH zcx_exed_ptax INTO DATA(error).
        cl_abap_unit_assert=>assert_equals(
          act = error->detail exp = 'Ativacao exige exatamente um rascunho.' ).
    ENDTRY.
  ENDMETHOD.

  METHOD failed_without_reported.
    DATA failed TYPE zcl_exed_ptax_rate_store=>failed_response.
    failed-exchangerate = VALUE #( (
      %pid = '00112233445566778899AABBCCDDEEFF'
      %fail-cause = if_abap_behv=>cause-not_found ) ).
    DATA(store) = NEW zcl_exed_ptax_rate_store( ).
    TRY.
        store->check_response( failed = failed reported = VALUE #( ) step = 'Activate' ).
        cl_abap_unit_assert=>fail( 'FAILED sem REPORTED deve manter a causa do erro.' ).
      CATCH zcx_exed_ptax INTO DATA(error).
        cl_abap_unit_assert=>assert_true(
          act = xsdbool( error->detail CS 'Activate' )
          msg = 'O diagnostico deve identificar a etapa que falhou.' ).
        cl_abap_unit_assert=>assert_true(
          act = xsdbool( error->detail CS 'NOT_FOUND' )
          msg = 'O diagnostico deve identificar a causa NOT_FOUND.' ).
        cl_abap_unit_assert=>assert_true(
          act = xsdbool( error->detail CS '404' )
          msg = 'O diagnostico deve incluir o codigo da causa RAP.' ).
    ENDTRY.
  ENDMETHOD.

  METHOD empty_response_is_success.
    DATA(store) = NEW zcl_exed_ptax_rate_store( ).
    store->check_response( failed = VALUE #( ) reported = VALUE #( ) step = 'Activate' ).
  ENDMETHOD.
ENDCLASS.
