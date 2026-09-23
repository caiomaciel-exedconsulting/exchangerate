CLASS zcl_exed_ptax_job DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES if_apj_rt_run.
    DATA p_reference TYPE d.
    DATA p_quotation TYPE d.
    DATA p_calendar TYPE c LENGTH 2 VALUE 'BR'.
    DATA p_timezone TYPE c LENGTH 6 VALUE 'BRAZIL'.
    DATA p_simulate TYPE abap_bool VALUE abap_true.
    DATA p_comsys TYPE c LENGTH 60.
  PRIVATE SECTION.
    METHODS add_text
      IMPORTING io_log TYPE REF TO if_bali_log
                iv_text TYPE string
                iv_severity TYPE if_bali_constants=>ty_severity
                  DEFAULT if_bali_constants=>c_severity_information
      RAISING cx_bali_runtime.
ENDCLASS.


CLASS zcl_exed_ptax_job IMPLEMENTATION.
  METHOD add_text.
    DATA(lv_remaining) = iv_text.
    WHILE lv_remaining IS NOT INITIAL.
      DATA(lv_length) = nmin( val1 = strlen( lv_remaining ) val2 = 200 ).
      io_log->add_item( cl_bali_free_text_setter=>create(
        severity = iv_severity text = CONV #( substring( val = lv_remaining len = lv_length ) ) ) ).
      lv_remaining = substring( val = lv_remaining off = lv_length ).
    ENDWHILE.
  ENDMETHOD.

  METHOD if_apj_rt_run~execute.
    DATA lo_log TYPE REF TO if_bali_log.
    DATA lv_finished TYPE abap_bool.
    DATA lv_errors TYPE i.
    TRY.
        lo_log = cl_bali_log=>create_with_header(
          cl_bali_header_setter=>create( object = 'ZEXED_PTAX' subobject = 'IMPORT' ) ).
        DATA(lv_reference) = p_reference.
        IF lv_reference IS INITIAL.
          DATA lv_now TYPE timestamp.
          GET TIME STAMP FIELD lv_now.
          IF p_timezone IS INITIAL.
            RAISE EXCEPTION NEW zcx_exed_ptax( detail = 'Informe o fuso SAP de Brasilia.' ).
          ENDIF.
          CONVERT TIME STAMP lv_now TIME ZONE p_timezone INTO DATE lv_reference.
          IF sy-subrc <> 0.
            RAISE EXCEPTION NEW zcx_exed_ptax( detail = |Fuso SAP invalido: { p_timezone }.| ).
          ENDIF.
        ENDIF.
        add_text( io_log = lo_log
          iv_text = |PTAX M/compra: referencia { lv_reference DATE = ISO }; calendario { p_calendar }; fuso { p_timezone }; simulacao { p_simulate }.| ).
        DATA(lo_service) = NEW zcl_exed_ptax_service(
          io_source = NEW zcl_exed_ptax_bacen( iv_comm_system = CONV #( p_comsys ) )
          io_calendar = NEW zcl_exed_ptax_calendar( )
          io_store = NEW zcl_exed_ptax_rate_store( ) ).
        DATA(ls_result) = lo_service->run(
          iv_reference_date = lv_reference iv_quotation_date = p_quotation
          iv_calendar_id = p_calendar iv_simulate = p_simulate ).
        lv_finished = abap_true.

        DATA lv_created TYPE i.
        DATA lv_updated TYPE i.
        DATA lv_equal TYPE i.
        DATA lv_skipped TYPE i.
        DATA lv_missing_currencies TYPE i.
        LOOP AT ls_result-quotes INTO DATA(ls_quote).
          IF ls_quote-found = abap_false.
            lv_missing_currencies += 1.
            add_text( io_log = lo_log iv_severity = if_bali_constants=>c_severity_warning
              iv_text = |{ ls_quote-currency }: sem Fechamento PTAX em { ls_result-quotation_date DATE = ISO }; nenhuma outra data consultada.| ).
          ELSE.
            add_text( io_log = lo_log iv_text =
              |{ ls_quote-currency }: compra { ls_quote-buy_rate }; boletim { ls_quote-bulletin_timestamp }.| ).
          ENDIF.
        ENDLOOP.
        LOOP AT ls_result-items INTO DATA(ls_item).
          CASE ls_item-action.
            WHEN zif_exed_ptax_types=>action_create. lv_created += 1.
            WHEN zif_exed_ptax_types=>action_update. lv_updated += 1.
            WHEN zif_exed_ptax_types=>action_unchanged. lv_equal += 1.
            WHEN zif_exed_ptax_types=>action_no_bulletin. lv_skipped += 1.
            WHEN zif_exed_ptax_types=>action_error. lv_errors += 1.
          ENDCASE.
          add_text( io_log = lo_log
            iv_severity = COND #( WHEN ls_item-action = zif_exed_ptax_types=>action_error
                                  THEN if_bali_constants=>c_severity_error
                                  ELSE if_bali_constants=>c_severity_information )
            iv_text =
            |{ ls_item-source_currency }/{ ls_item-target_currency } { ls_item-quotation } { ls_item-action }: { ls_item-absolute_rate }; fatores { ls_item-source_units }/{ ls_item-target_units }; { ls_item-message }| ).
        ENDLOOP.
        DATA(lv_mode) = COND string( WHEN p_simulate = abap_true THEN 'SIMULACAO - acoes previstas'
                                   ELSE 'MANUTENCAO - resultado confirmado' ).
        add_text( io_log = lo_log
          iv_severity = COND #( WHEN lv_errors > 0 THEN if_bali_constants=>c_severity_error
                                ELSE if_bali_constants=>c_severity_status )
          iv_text = |{ lv_mode }: criar={ lv_created }; atualizar={ lv_updated }; iguais={ lv_equal }; sem boletim={ lv_skipped } pares/{ lv_missing_currencies } moedas; erros={ lv_errors }.| ).
        cl_bali_log_db=>get_instance( )->save_log_2nd_db_connection(
          log = lo_log assign_to_current_appl_job = abap_true ).
      CATCH cx_root INTO DATA(lx_failure).
        DATA lv_error TYPE string.
        DATA(lo_cause) = lx_failure.
        DO 8 TIMES.
          IF lo_cause IS NOT BOUND.
            EXIT.
          ENDIF.
          lv_error = |{ lv_error } { lo_cause->get_text( ) }|.
          lo_cause = lo_cause->previous.
        ENDDO.
        IF lv_finished = abap_true AND p_simulate = abap_false.
          lv_error = |Processamento encerrado; falha posterior no log. Pode haver pares gravados; reconciliar antes de repetir. { lv_error }|.
        ENDIF.
        IF lo_log IS BOUND.
          TRY.
              add_text( io_log = lo_log iv_text = lv_error
                iv_severity = if_bali_constants=>c_severity_error ).
              cl_bali_log_db=>get_instance( )->save_log_2nd_db_connection(
                log = lo_log assign_to_current_appl_job = abap_true ).
            CATCH cx_bali_runtime INTO DATA(lx_log).
              lv_error = |{ lv_error } Falha adicional ao salvar log: { lx_log->get_text( ) }|.
          ENDTRY.
        ENDIF.
        RAISE EXCEPTION NEW cx_apj_rt_content(
          previous = NEW zcx_exed_ptax( detail = conv #( lv_error ) previous = lx_failure ) ).
    ENDTRY.
    IF lv_errors > 0.
      RAISE EXCEPTION NEW cx_apj_rt_content(
        previous = NEW zcx_exed_ptax(
          detail = |{ lv_errors } par(es) com erro. Sucessos preservados; consultar Application Log e reprocessar a mesma data.| ) ).
    ENDIF.
  ENDMETHOD.
ENDCLASS.
