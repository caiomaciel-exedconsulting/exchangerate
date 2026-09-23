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
    TYPES BEGIN OF execution_dates.
    TYPES reference_date TYPE d.
    TYPES quotation_date TYPE d.
    TYPES END OF execution_dates.
    METHODS resolve_dates
      IMPORTING current_timestamp TYPE timestamp
      RETURNING VALUE(dates) TYPE execution_dates
      RAISING zcx_exed_ptax.
    METHODS add_text
      IMPORTING log      TYPE REF TO if_bali_log
                text     TYPE string
                severity TYPE if_bali_constants=>ty_severity
                  DEFAULT if_bali_constants=>c_severity_information
      RAISING   cx_bali_runtime.
ENDCLASS.


CLASS zcl_exed_ptax_job IMPLEMENTATION.

  METHOD resolve_dates.
    dates-reference_date = p_reference.
    dates-quotation_date = p_quotation.
    " O agendamento pode fornecer oito espaços; INITIAL de D é 00000000.
    IF dates-reference_date CO space.
      CLEAR dates-reference_date.
    ENDIF.
    IF dates-quotation_date CO space.
      CLEAR dates-quotation_date.
    ENDIF.
    IF dates-reference_date IS INITIAL.
      IF p_timezone IS INITIAL.
        RAISE EXCEPTION NEW zcx_exed_ptax( detail = 'Informe o fuso SAP de Brasilia.' ).
      ENDIF.
      CONVERT TIME STAMP current_timestamp TIME ZONE p_timezone INTO DATE dates-reference_date.
      IF sy-subrc <> 0.
        RAISE EXCEPTION NEW zcx_exed_ptax( detail = |Fuso SAP invalido: { p_timezone }.| ).
      ENDIF.
    ENDIF.

    DATA date_timestamp TYPE timestamp.
    " A cotação explícita tem prioridade; a referência só define a data automática.
    IF dates-quotation_date IS INITIAL.
      CONVERT DATE dates-reference_date TIME '000000'
        INTO TIME STAMP date_timestamp TIME ZONE 'UTC'.
      IF sy-subrc <> 0 OR dates-reference_date IS INITIAL.
        RAISE EXCEPTION NEW zcx_exed_ptax( detail = 'P_REFERENCE contem uma data invalida.' ).
      ENDIF.
    ELSE.
      CONVERT DATE dates-quotation_date TIME '000000'
        INTO TIME STAMP date_timestamp TIME ZONE 'UTC'.
      IF sy-subrc <> 0.
        RAISE EXCEPTION NEW zcx_exed_ptax( detail = 'P_QUOTATION contem uma data invalida.' ).
      ENDIF.
    ENDIF.
  ENDMETHOD.

  METHOD add_text.
    DATA(remaining_text) = text.
    WHILE remaining_text IS NOT INITIAL.
      DATA(segment_length) = nmin( val1 = strlen( remaining_text ) val2 = 200 ).
      log->add_item( cl_bali_free_text_setter=>create(
        severity = severity text = CONV #( substring( val = remaining_text len = segment_length ) ) ) ).
      remaining_text = substring( val = remaining_text off = segment_length ).
    ENDWHILE.
  ENDMETHOD.

  METHOD if_apj_rt_run~execute.
    DATA log TYPE REF TO if_bali_log.
    DATA finished TYPE abap_bool.
    DATA error_count TYPE i.
    TRY.
        log = cl_bali_log=>create_with_header(
          cl_bali_header_setter=>create( object = 'ZEXED_PTAX' subobject = 'IMPORT' ) ).
        DATA current_timestamp TYPE timestamp.
        GET TIME STAMP FIELD current_timestamp.
        DATA(dates) = resolve_dates( current_timestamp ).
        DATA(quotation_text) = COND string( WHEN dates-quotation_date IS INITIAL
          THEN 'automatica pelo calendario' ELSE |{ dates-quotation_date DATE = ISO }| ).
        DATA(mode_text) = COND string( WHEN p_simulate = abap_true
          THEN 'SIMULACAO' ELSE 'MANUTENCAO' ).
        add_text( log = log
          text = |PTAX M/compra: referencia { dates-reference_date DATE = ISO }; cotacao { quotation_text }; calendario { p_calendar }; fuso { p_timezone }; modo { mode_text }.| ).
        DATA(service) = NEW zcl_exed_ptax_service(
          source = NEW zcl_exed_ptax_bacen( communication_system = CONV #( p_comsys ) )
          calendar = NEW zcl_exed_ptax_calendar( )
          store = NEW zcl_exed_ptax_rate_store( ) ).
        DATA(result) = service->run(
          reference_date = dates-reference_date quotation_date = dates-quotation_date
          calendar_id = p_calendar simulate = p_simulate ).
        finished = abap_true.

        DATA created_count TYPE i.
        DATA updated_count TYPE i.
        DATA equal_count TYPE i.
        DATA skipped_count TYPE i.
        DATA missing_currency_count TYPE i.
        LOOP AT result-quotes INTO DATA(quote).
          IF quote-found = abap_false.
            missing_currency_count += 1.
            add_text( log = log severity = if_bali_constants=>c_severity_warning
              text = |{ quote-currency }: sem Fechamento PTAX em { result-quotation_date DATE = ISO }; nenhuma outra data consultada.| ).
          ELSE.
            add_text( log = log text =
              |{ quote-currency }: compra { quote-buy_rate }; boletim { quote-bulletin_timestamp }.| ).
          ENDIF.
        ENDLOOP.
        LOOP AT result-items INTO DATA(item).
          CASE item-action.
            WHEN zif_exed_ptax_types=>action_create. created_count += 1.
            WHEN zif_exed_ptax_types=>action_update. updated_count += 1.
            WHEN zif_exed_ptax_types=>action_unchanged. equal_count += 1.
            WHEN zif_exed_ptax_types=>action_no_bulletin. skipped_count += 1.
            WHEN zif_exed_ptax_types=>action_error. error_count += 1.
          ENDCASE.
          add_text( log = log
            severity = COND #( WHEN item-action = zif_exed_ptax_types=>action_error
                                  THEN if_bali_constants=>c_severity_error
                                  ELSE if_bali_constants=>c_severity_information )
            text =
            |{ item-source_currency }/{ item-target_currency } { item-quotation } { item-action }: { item-absolute_rate }; fatores { item-source_units }/{ item-target_units }; { item-message }| ).
        ENDLOOP.
        DATA(execution_mode) = COND string( WHEN p_simulate = abap_true THEN 'SIMULACAO - acoes previstas'
                                   ELSE 'MANUTENCAO - resultado confirmado' ).
        add_text( log = log
          severity = COND #( WHEN error_count > 0 THEN if_bali_constants=>c_severity_error
                                ELSE if_bali_constants=>c_severity_status )
          text = |{ execution_mode }: criar={ created_count }; atualizar={ updated_count }; iguais={ equal_count }; sem boletim={ skipped_count } pares/{ missing_currency_count } moedas; erros={ error_count }.| ).
        cl_bali_log_db=>get_instance( )->save_log_2nd_db_connection(
          log = log assign_to_current_appl_job = abap_true ).
      CATCH cx_root INTO DATA(failure).
        DATA error_text TYPE string.
        DATA(cause) = failure.
        DO 8 TIMES.
          IF cause IS NOT BOUND.
            EXIT.
          ENDIF.
          error_text = |{ error_text } { cause->get_text( ) }|.
          cause = cause->previous.
        ENDDO.
        IF finished = abap_true AND p_simulate = abap_false.
          error_text = |Processamento encerrado; falha posterior no log. Pode haver pares gravados; reconciliar antes de repetir. { error_text }|.
        ENDIF.
        IF log IS BOUND.
          TRY.
              add_text( log = log text = error_text
                severity = if_bali_constants=>c_severity_error ).
              cl_bali_log_db=>get_instance( )->save_log_2nd_db_connection(
                log = log assign_to_current_appl_job = abap_true ).
            CATCH cx_bali_runtime INTO DATA(log_error).
              error_text = |{ error_text } Falha adicional ao salvar log: { log_error->get_text( ) }|.
          ENDTRY.
        ENDIF.
        RAISE EXCEPTION NEW cx_apj_rt_content( previous = NEW zcx_exed_ptax( detail = error_text previous = failure ) ).
    ENDTRY.
    IF error_count > 0.
      RAISE EXCEPTION NEW cx_apj_rt_content( previous = NEW zcx_exed_ptax(
                                               detail = |{ error_count } par(es) com erro. Sucessos preservados; consultar Application Log e reprocessar a mesma data.| ) ).
    ENDIF.
  ENDMETHOD.
ENDCLASS.
