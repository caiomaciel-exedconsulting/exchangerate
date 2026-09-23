CLASS zcl_exed_ptax_calendar DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES zif_exed_ptax_calendar.
  PRIVATE SECTION.
    METHODS calculate_before
      IMPORTING iv_reference_date TYPE d
                io_runtime TYPE REF TO if_fhc_fcal_runtime
      RETURNING VALUE(rv_date) TYPE d
      RAISING zcx_exed_ptax.
ENDCLASS.

CLASS zcl_exed_ptax_calendar IMPLEMENTATION.
  METHOD zif_exed_ptax_calendar~previous_workday.
    IF iv_calendar_id IS INITIAL.
      RAISE EXCEPTION NEW zcx_exed_ptax( detail = 'Factory calendar ID is required' ).
    ENDIF.
    TRY.
        DATA(lo_mapper) = cl_fhc_calendar_id_mapper=>create_id_mapper( ).
        DATA(lv_calendar_id) = lo_mapper->mapping_fcal_legacyid_to_id(
          iv_legacy_id = CONV #( iv_calendar_id ) ).
        IF lv_calendar_id IS INITIAL.
          RAISE EXCEPTION NEW zcx_exed_ptax(
            detail = |Factory calendar { iv_calendar_id } has no FHC mapping| ).
        ENDIF.
        DATA(lo_runtime) = cl_fhc_calendar_runtime=>create_factorycalendar_runtime(
          iv_factorycalendar_id = lv_calendar_id ).
        rv_date = calculate_before( iv_reference_date = iv_reference_date
                                    io_runtime = lo_runtime ).
      CATCH cx_fhc_runtime INTO DATA(lx_calendar).
        RAISE EXCEPTION NEW zcx_exed_ptax(
          detail = |Factory calendar { iv_calendar_id } cannot be resolved|
          previous = lx_calendar ).
    ENDTRY.
  ENDMETHOD.

  METHOD calculate_before.
    IF io_runtime IS NOT BOUND OR iv_reference_date <= '00010101'.
      RAISE EXCEPTION NEW zcx_exed_ptax( detail = 'Invalid reference date or calendar runtime' ).
    ENDIF.
    TRY.
        cl_abap_datfm=>conv_date_ext_to_int(
          EXPORTING im_datext = |{ iv_reference_date+0(4) }-{ iv_reference_date+4(2) }-{ iv_reference_date+6(2) }|
                    im_datfmdes = '6'
          IMPORTING ex_datint = DATA(lv_valid_date) ).
      CATCH cx_abap_datfm_no_date cx_abap_datfm_invalid_date
            cx_abap_datfm_format_unknown cx_abap_datfm_ambiguous INTO DATA(lx_date).
        RAISE EXCEPTION NEW zcx_exed_ptax( detail = 'Invalid reference date' previous = lx_date ).
    ENDTRY.
    DATA(lv_limit) = CONV d( lv_valid_date - 1 ).
    IF lv_limit < io_runtime->get_validity_start( )
       OR lv_limit > io_runtime->get_validity_end( ).
      RAISE EXCEPTION NEW zcx_exed_ptax(
        detail = |Factory calendar does not cover { lv_limit DATE = ISO }| ).
    ENDIF.
    TRY.
        DATA(lv_factorydate) = io_runtime->convert_date_to_factorydate(
          iv_date = lv_limit
          iv_correct_option = if_fhc_fcal_runtime=>gc_correct_option_minus ).
        rv_date = io_runtime->convert_factorydate_to_date( iv_factorydate = lv_factorydate ).
        IF rv_date IS INITIAL OR rv_date > lv_limit
           OR rv_date < io_runtime->get_validity_start( )
           OR rv_date > io_runtime->get_validity_end( ).
          RAISE EXCEPTION NEW zcx_exed_ptax(
            detail = 'Calendar returned an invalid previous working day' ).
        ENDIF.
      CATCH cx_fhc_runtime INTO DATA(lx_runtime).
        RAISE EXCEPTION NEW zcx_exed_ptax(
          detail = |Cannot determine working day before { iv_reference_date DATE = ISO }|
          previous = lx_runtime ).
    ENDTRY.
  ENDMETHOD.
ENDCLASS.
