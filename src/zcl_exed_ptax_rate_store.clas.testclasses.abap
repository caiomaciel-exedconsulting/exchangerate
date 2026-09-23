CLASS ltc_rate_store DEFINITION DEFERRED.
CLASS zcl_exed_ptax_rate_store DEFINITION LOCAL FRIENDS ltc_rate_store.

CLASS ltc_rate_store DEFINITION FINAL FOR TESTING
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

CLASS ltc_rate_store IMPLEMENTATION.
  METHOD direct_nonunit_factors.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_exed_ptax_rate_store=>normalize(
        iv_buy_rate = '5.1234' iv_quotation = 'D'
        is_factors = VALUE #( source_units = 100 target_units = 1 ) )
      exp = CONV zif_exed_ptax_types=>ty_rate( '512.34' ) ).
  ENDMETHOD.

  METHOD indirect_nonunit_factors.
    "Indirect notation preserves the BACEN value; it does not take its reciprocal.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_exed_ptax_rate_store=>normalize(
        iv_buy_rate = '5.1234' iv_quotation = 'I'
        is_factors = VALUE #( source_units = 1 target_units = 100 ) )
      exp = CONV zif_exed_ptax_types=>ty_rate( '512.34' ) ).
  ENDMETHOD.

  METHOD sap_precision.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_exed_ptax_rate_store=>normalize(
        iv_buy_rate = '5.123456' iv_quotation = 'D'
        is_factors = VALUE #( source_units = 1 target_units = 1 ) )
      exp = CONV zif_exed_ptax_types=>ty_rate( '5.12346' ) ).
  ENDMETHOD.

  METHOD indirect_signed_comparison.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_exed_ptax_rate_store=>signed_rate(
        iv_absolute = CONV #( '5.1234' ) iv_quotation = 'I' )
      exp = CONV zif_exed_ptax_types=>ty_rate( '-5.1234' ) ).
  ENDMETHOD.

  METHOD invalid_factor.
    TRY.
        DATA(lv_rate) = zcl_exed_ptax_rate_store=>normalize(
          iv_buy_rate = 5 iv_quotation = 'D'
          is_factors = VALUE #( source_units = 1 target_units = 0 ) ).
        cl_abap_unit_assert=>fail( 'Zero factor must fail.' ).
      CATCH zcx_exed_ptax.
    ENDTRY.
  ENDMETHOD.

  METHOD zero_after_rounding.
    TRY.
        DATA(lv_rate) = zcl_exed_ptax_rate_store=>normalize(
          iv_buy_rate = '0.00000001' iv_quotation = 'D'
          is_factors = VALUE #( source_units = 1 target_units = 1 ) ).
        cl_abap_unit_assert=>fail( 'Unrepresentable positive rate must fail.' ).
      CATCH zcx_exed_ptax.
    ENDTRY.
  ENDMETHOD.

  METHOD overflow.
    TRY.
        DATA(lv_rate) = zcl_exed_ptax_rate_store=>normalize(
          iv_buy_rate = '1E30' iv_quotation = 'D'
          is_factors = VALUE #( source_units = 100 target_units = 1 ) ).
        cl_abap_unit_assert=>fail( 'Overflow must fail.' ).
      CATCH zcx_exed_ptax.
    ENDTRY.
  ENDMETHOD.

  METHOD invalid_notation.
    TRY.
        DATA(lv_rate) = zcl_exed_ptax_rate_store=>normalize(
          iv_buy_rate = 5 iv_quotation = 'X'
          is_factors = VALUE #( source_units = 1 target_units = 1 ) ).
        cl_abap_unit_assert=>fail( 'Invalid quotation must fail.' ).
      CATCH zcx_exed_ptax.
    ENDTRY.
  ENDMETHOD.
ENDCLASS.
