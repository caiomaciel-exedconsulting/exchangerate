CLASS job_tests DEFINITION DEFERRED.
CLASS zcl_exed_ptax_job DEFINITION LOCAL FRIENDS job_tests.

CLASS job_tests DEFINITION FINAL FOR TESTING DURATION SHORT RISK LEVEL HARMLESS.
  PRIVATE SECTION.
    METHODS initial_dates_use_today FOR TESTING RAISING zcx_exed_ptax.
    METHODS blank_dates_use_today FOR TESTING RAISING zcx_exed_ptax.
    METHODS explicit_reference_kept FOR TESTING RAISING zcx_exed_ptax.
    METHODS explicit_quotation_kept FOR TESTING RAISING zcx_exed_ptax.
    METHODS reject_invalid_reference FOR TESTING.
    METHODS reject_invalid_quotation FOR TESTING.
    METHODS reject_invalid_timezone FOR TESTING.
ENDCLASS.

CLASS job_tests IMPLEMENTATION.
  METHOD initial_dates_use_today.
    DATA(job) = NEW zcl_exed_ptax_job( ).
    job->p_timezone = 'UTC'.
    DATA(dates) = job->resolve_dates( CONV timestamp( '20260923070000' ) ).
    cl_abap_unit_assert=>assert_equals( act = dates-reference_date exp = '20260923' ).
    cl_abap_unit_assert=>assert_initial( dates-quotation_date ).
  ENDMETHOD.

  METHOD blank_dates_use_today.
    DATA(job) = NEW zcl_exed_ptax_job( ).
    job->p_timezone = 'UTC'.
    job->p_reference = '        '.
    job->p_quotation = '        '.
    " Reproduzir a entrada que não é INITIAL apesar de aparecer vazia na tela.
    cl_abap_unit_assert=>assert_not_initial( job->p_reference ).
    cl_abap_unit_assert=>assert_not_initial( job->p_quotation ).
    DATA(dates) = job->resolve_dates( CONV timestamp( '20260923070000' ) ).
    cl_abap_unit_assert=>assert_equals( act = dates-reference_date exp = '20260923' ).
    cl_abap_unit_assert=>assert_initial( dates-quotation_date ).
  ENDMETHOD.

  METHOD explicit_reference_kept.
    DATA(job) = NEW zcl_exed_ptax_job( ).
    job->p_reference = '20260406'.
    job->p_quotation = '        '.
    DATA(dates) = job->resolve_dates( CONV timestamp( '20260923070000' ) ).
    cl_abap_unit_assert=>assert_equals( act = dates-reference_date exp = '20260406' ).
    cl_abap_unit_assert=>assert_initial( dates-quotation_date ).
  ENDMETHOD.

  METHOD explicit_quotation_kept.
    DATA(job) = NEW zcl_exed_ptax_job( ).
    job->p_reference = '20260406'.
    job->p_quotation = '20260402'.
    DATA(dates) = job->resolve_dates( CONV timestamp( '20260923070000' ) ).
    cl_abap_unit_assert=>assert_equals( act = dates-reference_date exp = '20260406' ).
    cl_abap_unit_assert=>assert_equals( act = dates-quotation_date exp = '20260402' ).
  ENDMETHOD.

  METHOD reject_invalid_reference.
    DATA(job) = NEW zcl_exed_ptax_job( ).
    job->p_reference = '20260230'.
    TRY.
        job->resolve_dates( CONV timestamp( '20260923070000' ) ).
        cl_abap_unit_assert=>fail( 'Uma referencia invalida deve ser recusada.' ).
      CATCH zcx_exed_ptax INTO DATA(failure).
        cl_abap_unit_assert=>assert_equals(
          act = failure->get_text( ) exp = 'P_REFERENCE contem uma data invalida.' ).
    ENDTRY.
  ENDMETHOD.

  METHOD reject_invalid_quotation.
    DATA(job) = NEW zcl_exed_ptax_job( ).
    job->p_reference = '20260923'.
    job->p_quotation = '20260230'.
    TRY.
        job->resolve_dates( CONV timestamp( '20260923070000' ) ).
        cl_abap_unit_assert=>fail( 'Uma cotacao invalida deve ser recusada.' ).
      CATCH zcx_exed_ptax INTO DATA(failure).
        cl_abap_unit_assert=>assert_equals(
          act = failure->get_text( ) exp = 'P_QUOTATION contem uma data invalida.' ).
    ENDTRY.
  ENDMETHOD.

  METHOD reject_invalid_timezone.
    DATA(job) = NEW zcl_exed_ptax_job( ).
    job->p_timezone = '______'.
    TRY.
        job->resolve_dates( CONV timestamp( '20260923070000' ) ).
        cl_abap_unit_assert=>fail( 'Um fuso invalido deve ser recusado.' ).
      CATCH zcx_exed_ptax INTO DATA(failure).
        cl_abap_unit_assert=>assert_equals(
          act = failure->get_text( ) exp = 'Fuso SAP invalido: ______.' ).
    ENDTRY.
  ENDMETHOD.
ENDCLASS.
