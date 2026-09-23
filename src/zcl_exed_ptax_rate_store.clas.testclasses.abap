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
ENDCLASS.
