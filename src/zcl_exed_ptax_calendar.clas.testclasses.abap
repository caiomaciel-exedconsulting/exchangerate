CLASS ltc_calendar DEFINITION DEFERRED.
CLASS zcl_exed_ptax_calendar DEFINITION LOCAL FRIENDS ltc_calendar.

CLASS lcl_factory_calendar DEFINITION FINAL.
  PUBLIC SECTION.
    INTERFACES if_fhc_fcal_runtime.
    DATA requested_date TYPE d.
    DATA requested_option TYPE if_fhc_fcal_runtime=>te_correct_option.
    DATA result_date TYPE d VALUE '20240328'.
    DATA validity_start TYPE d VALUE '20240101'.
    DATA validity_end TYPE d VALUE '20251231'.
    DATA conversion_count TYPE i.
ENDCLASS.

CLASS lcl_factory_calendar IMPLEMENTATION.
  METHOD if_fhc_fcal_runtime~convert_date_to_factorydate.
    requested_date = iv_date.
    requested_option = iv_correct_option.
    conversion_count += 1.
    rv_factorydate = 42.
  ENDMETHOD.
  METHOD if_fhc_fcal_runtime~convert_factorydate_to_date.
    cl_abap_unit_assert=>assert_equals( act = iv_factorydate exp = 42 ).
    rv_date = result_date.
  ENDMETHOD.
  METHOD if_fhc_fcal_runtime~get_validity_start.
    rv_validity_start = validity_start.
  ENDMETHOD.
  METHOD if_fhc_fcal_runtime~get_validity_end.
    rv_validity_end = validity_end.
  ENDMETHOD.
  METHOD if_fhc_fcal_runtime~get_last_factorydate.
  ENDMETHOD.
  METHOD if_fhc_fcal_runtime~calc_workingdays_between_dates.
  ENDMETHOD.
  METHOD if_fhc_fcal_runtime~add_workingdays_to_date.
  ENDMETHOD.
  METHOD if_fhc_fcal_runtime~subtract_workingdays_from_date.
    cl_abap_unit_assert=>fail( 'Must correct reference minus one day, not subtract one working day' ).
  ENDMETHOD.
  METHOD if_fhc_fcal_runtime~is_workingday.
  ENDMETHOD.
  METHOD if_fhc_fcal_runtime~is_holiday_workingday.
  ENDMETHOD.
  METHOD if_fhc_fcal_runtime~is_date_workingday.
  ENDMETHOD.
  METHOD if_fhc_fcal_runtime~get_description.
  ENDMETHOD.
  METHOD if_fhc_fcal_runtime~get_hcal_assignment.
  ENDMETHOD.
  METHOD if_fhc_fcal_runtime~get_id.
  ENDMETHOD.
ENDCLASS.

CLASS ltc_calendar DEFINITION FINAL FOR TESTING DURATION SHORT RISK LEVEL HARMLESS.
  PRIVATE SECTION.
    DATA mo_cut TYPE REF TO zcl_exed_ptax_calendar.
    DATA mo_runtime TYPE REF TO lcl_factory_calendar.
    METHODS setup.
    METHODS previous_day_corrected_back FOR TESTING RAISING zcx_exed_ptax.
    METHODS year_boundary FOR TESTING RAISING zcx_exed_ptax.
    METHODS reject_uncovered_dates FOR TESTING.
    METHODS reject_invalid_dates FOR TESTING.
    METHODS reject_later_result FOR TESTING.
ENDCLASS.

CLASS ltc_calendar IMPLEMENTATION.
  METHOD setup.
    mo_cut = NEW #( ).
    mo_runtime = NEW #( ).
  ENDMETHOD.

  METHOD previous_day_corrected_back.
    " Segunda após a Sexta-feira Santa: o calendário simulado retorna quinta.
    DATA(lv_date) = mo_cut->calculate_before( iv_reference_date = '20240401' io_runtime = mo_runtime ).
    cl_abap_unit_assert=>assert_equals( act = mo_runtime->requested_date exp = '20240331' ).
    cl_abap_unit_assert=>assert_equals( act = mo_runtime->requested_option
      exp = if_fhc_fcal_runtime=>gc_correct_option_minus ).
    cl_abap_unit_assert=>assert_equals( act = lv_date exp = '20240328' ).
    " No domingo, a busca parte de sábado e exclui a própria data de referência.
    lv_date = mo_cut->calculate_before( iv_reference_date = '20240331' io_runtime = mo_runtime ).
    cl_abap_unit_assert=>assert_equals( act = mo_runtime->requested_date exp = '20240330' ).
  ENDMETHOD.

  METHOD year_boundary.
    mo_runtime->result_date = '20241231'.
    DATA(lv_date) = mo_cut->calculate_before( iv_reference_date = '20250101' io_runtime = mo_runtime ).
    cl_abap_unit_assert=>assert_equals( act = mo_runtime->requested_date exp = '20241231' ).
    cl_abap_unit_assert=>assert_equals( act = lv_date exp = '20241231' ).
  ENDMETHOD.

  METHOD reject_uncovered_dates.
    TRY.
        mo_cut->calculate_before( iv_reference_date = '20240101' io_runtime = mo_runtime ).
        cl_abap_unit_assert=>fail( 'No calendar coverage must be an error' ).
      CATCH zcx_exed_ptax.
    ENDTRY.
    cl_abap_unit_assert=>assert_initial( mo_runtime->conversion_count ).
    TRY.
        mo_cut->calculate_before( iv_reference_date = '20260102' io_runtime = mo_runtime ).
        cl_abap_unit_assert=>fail( 'Dates after coverage must be an error' ).
      CATCH zcx_exed_ptax.
    ENDTRY.
    cl_abap_unit_assert=>assert_initial( mo_runtime->conversion_count ).
  ENDMETHOD.

  METHOD reject_invalid_dates.
    TRY.
        mo_cut->calculate_before( iv_reference_date = '20240230' io_runtime = mo_runtime ).
        cl_abap_unit_assert=>fail( 'Invalid date must be an error' ).
      CATCH zcx_exed_ptax.
    ENDTRY.
    TRY.
        mo_cut->calculate_before( iv_reference_date = '00010101' io_runtime = mo_runtime ).
        cl_abap_unit_assert=>fail( 'Earliest date cannot have a previous working day' ).
      CATCH zcx_exed_ptax.
    ENDTRY.
    cl_abap_unit_assert=>assert_initial( mo_runtime->conversion_count ).
  ENDMETHOD.

  METHOD reject_later_result.
    mo_runtime->result_date = '20240401'.
    TRY.
        mo_cut->calculate_before( iv_reference_date = '20240401' io_runtime = mo_runtime ).
        cl_abap_unit_assert=>fail( 'Result must be strictly before the reference date' ).
      CATCH zcx_exed_ptax.
    ENDTRY.
  ENDMETHOD.
ENDCLASS.
