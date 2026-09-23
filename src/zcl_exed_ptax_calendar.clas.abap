CLASS zcl_exed_ptax_calendar DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES zif_exed_ptax_calendar.
  PRIVATE SECTION.
    METHODS calculate_before
      IMPORTING reference_date TYPE d
                factory_calendar TYPE REF TO if_fhc_fcal_runtime
      RETURNING VALUE(workday) TYPE d
      RAISING zcx_exed_ptax.
ENDCLASS.

CLASS zcl_exed_ptax_calendar IMPLEMENTATION.
  METHOD zif_exed_ptax_calendar~previous_workday.
    IF calendar_id IS INITIAL.
      RAISE EXCEPTION NEW zcx_exed_ptax( detail = 'Factory calendar ID is required' ).
    ENDIF.
    TRY.
        DATA(calendar_mapper) = cl_fhc_calendar_id_mapper=>create_id_mapper( ).
        DATA(factory_calendar_id) = calendar_mapper->mapping_fcal_legacyid_to_id(
          iv_legacy_id = CONV #( calendar_id ) ).
        IF factory_calendar_id IS INITIAL.
          RAISE EXCEPTION NEW zcx_exed_ptax(
            detail = |Factory calendar { calendar_id } has no FHC mapping| ).
        ENDIF.
        DATA(factory_calendar) = cl_fhc_calendar_runtime=>create_factorycalendar_runtime(
          iv_factorycalendar_id = factory_calendar_id ).
        workday = calculate_before( reference_date = reference_date
                                    factory_calendar = factory_calendar ).
      CATCH cx_fhc_runtime INTO DATA(calendar_error).
        RAISE EXCEPTION NEW zcx_exed_ptax(
          detail = |Factory calendar { calendar_id } cannot be resolved|
          previous = calendar_error ).
    ENDTRY.
  ENDMETHOD.

  METHOD calculate_before.
    IF factory_calendar IS NOT BOUND OR reference_date <= '00010101'.
      RAISE EXCEPTION NEW zcx_exed_ptax( detail = 'Invalid reference date or calendar runtime' ).
    ENDIF.
    TRY.
        cl_abap_datfm=>conv_date_ext_to_int(
          EXPORTING im_datext = |{ reference_date+0(4) }-{ reference_date+4(2) }-{ reference_date+6(2) }|
                    im_datfmdes = '6'
          IMPORTING ex_datint = DATA(valid_date) ).
      CATCH cx_abap_datfm_no_date cx_abap_datfm_invalid_date
            cx_abap_datfm_format_unknown cx_abap_datfm_ambiguous INTO DATA(date_error).
        RAISE EXCEPTION NEW zcx_exed_ptax( detail = 'Invalid reference date' previous = date_error ).
    ENDTRY.
    DATA(last_possible_date) = CONV d( valid_date - 1 ).
    IF last_possible_date < factory_calendar->get_validity_start( )
       OR last_possible_date > factory_calendar->get_validity_end( ).
      RAISE EXCEPTION NEW zcx_exed_ptax(
        detail = |Factory calendar does not cover { last_possible_date DATE = ISO }| ).
    ENDIF.
    TRY.
        DATA(factory_date) = factory_calendar->convert_date_to_factorydate(
          iv_date = last_possible_date
          iv_correct_option = if_fhc_fcal_runtime=>gc_correct_option_minus ).
        workday = factory_calendar->convert_factorydate_to_date( iv_factorydate = factory_date ).
        IF workday IS INITIAL OR workday > last_possible_date
           OR workday < factory_calendar->get_validity_start( )
           OR workday > factory_calendar->get_validity_end( ).
          RAISE EXCEPTION NEW zcx_exed_ptax(
            detail = 'Calendar returned an invalid previous working day' ).
        ENDIF.
      CATCH cx_fhc_runtime INTO DATA(calendar_error).
        RAISE EXCEPTION NEW zcx_exed_ptax(
          detail = |Cannot determine working day before { reference_date DATE = ISO }|
          previous = calendar_error ).
    ENDTRY.
  ENDMETHOD.
ENDCLASS.
