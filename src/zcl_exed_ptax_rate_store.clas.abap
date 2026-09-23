CLASS zcl_exed_ptax_rate_store DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES zif_exed_ptax_rate_store.
  PRIVATE SECTION.
    TYPES:
      BEGIN OF conversion_factors,
        source_units TYPE decfloat34,
        target_units TYPE decfloat34,
      END OF conversion_factors,
      BEGIN OF stored_rate,
        found       TYPE abap_bool,
        signed_rate TYPE zif_exed_ptax_types=>exchange_rate,
      END OF stored_rate.
    TYPES failed_response TYPE RESPONSE FOR FAILED EARLY i_currencyexchangeratetp_2.
    TYPES reported_response TYPE RESPONSE FOR REPORTED EARLY i_currencyexchangeratetp_2.
    TYPES rate_keys TYPE TABLE FOR READ IMPORT i_currencyexchangeratetp_2.
    TYPES activation_requests TYPE TABLE FOR ACTION IMPORT i_currencyexchangeratetp_2~Activate.
    CLASS-METHODS build_activation_requests
      IMPORTING keys TYPE rate_keys
      RETURNING VALUE(requests) TYPE activation_requests
      RAISING zcx_exed_ptax.
    CLASS-METHODS normalize
      IMPORTING buy_rate    TYPE decfloat34
                quotation   TYPE zif_exed_ptax_types=>quotation_notation
                factors     TYPE conversion_factors
      RETURNING VALUE(rate) TYPE zif_exed_ptax_types=>exchange_rate
      RAISING   zcx_exed_ptax.
    CLASS-METHODS signed_rate
      IMPORTING absolute_rate    TYPE zif_exed_ptax_types=>exchange_rate
                quotation   TYPE zif_exed_ptax_types=>quotation_notation
      RETURNING VALUE(rate) TYPE zif_exed_ptax_types=>exchange_rate
      RAISING   zcx_exed_ptax.
    METHODS read_factors
      IMPORTING pair TYPE zif_exed_ptax_types=>currency_pair requested_date TYPE d
      RETURNING VALUE(factors) TYPE conversion_factors
      RAISING zcx_exed_ptax.
    METHODS read_current
      IMPORTING item           TYPE zif_exed_ptax_types=>rate_item
      RETURNING VALUE(current_rate) TYPE stored_rate.
    METHODS revalidate
      IMPORTING item TYPE zif_exed_ptax_types=>rate_item
      RAISING   zcx_exed_ptax.
    METHODS check_response
      IMPORTING failed TYPE failed_response reported TYPE reported_response
                step TYPE string
      RAISING zcx_exed_ptax.
    METHODS stage_one
      IMPORTING item TYPE zif_exed_ptax_types=>rate_item
      RAISING   zcx_exed_ptax.
ENDCLASS.

CLASS zcl_exed_ptax_rate_store IMPLEMENTATION.
  METHOD normalize.
    IF buy_rate <= 0 OR factors-source_units <= 0
       OR factors-target_units <= 0.
      RAISE EXCEPTION NEW zcx_exed_ptax( detail = 'Cotacao e fatore devem ser positivos.' ).
    ENDIF.
    TRY.
        DATA normalized_value TYPE decfloat34.
        CASE quotation.
          WHEN 'D'.
            normalized_value = buy_rate * factors-source_units / factors-target_units.
          WHEN 'I'.
            normalized_value = buy_rate * factors-target_units / factors-source_units.
          WHEN OTHERS.
            RAISE EXCEPTION NEW zcx_exed_ptax( detail = 'Notacao deve ser D ou I.' ).
        ENDCASE.
        "O campo liberado da BOI define a precisão e o arredondamento do valor.
        rate = CONV #( normalized_value ).
      CATCH cx_sy_arithmetic_error cx_sy_conversion_error INTO DATA(numeric_error).
        RAISE EXCEPTION NEW zcx_exed_ptax( detail   = 'Cotacao excede a representacao do campo SAP.'
                                           previous = numeric_error ).
    ENDTRY.
    IF rate <= 0.
      RAISE EXCEPTION NEW zcx_exed_ptax( detail = 'Cotacao ficou zero apos arredondamento.' ).
    ENDIF.
  ENDMETHOD.

  METHOD signed_rate.
    CASE quotation.
      WHEN 'D'. rate = absolute_rate.
      WHEN 'I'. rate = - absolute_rate.
      WHEN OTHERS.
        RAISE EXCEPTION NEW zcx_exed_ptax( detail = 'Notacao deve ser D ou I.' ).
    ENDCASE.
  ENDMETHOD.

  METHOD read_factors.
    DATA(source_currency) = pair-source_currency.
    DATA(target_currency) = pair-target_currency.
    IF pair-quotation = 'I'.
      "A BOI resolve fatores indiretos usando o par de moedas inverso.
      source_currency = pair-target_currency.
      target_currency = pair-source_currency.
    ELSEIF pair-quotation <> 'D'.
      RAISE EXCEPTION NEW zcx_exed_ptax( detail = 'Notacao deve ser D ou I.' ).
    ENDIF.
    SELECT NumberOfSourceCurrencyUnits, NumberOfTargetCurrencyUnits,
           AlternativeExchangeRateType, AltvExchangeRateTypeValdtyDate
      FROM I_ExchangeRateFactorsRawData
      WHERE ExchangeRateType = @zif_exed_ptax_types=>exchange_rate_type
        AND SourceCurrency = @source_currency AND TargetCurrency = @target_currency
        AND ValidityStartDate <= @requested_date
      ORDER BY ValidityStartDate DESCENDING
      INTO TABLE @DATA(factor_records)
      UP TO 1 ROWS.
    IF factor_records IS INITIAL.
      RAISE EXCEPTION NEW zcx_exed_ptax( detail = |Sem fatores M { source_currency }/{ target_currency } validos em { requested_date DATE = ISO }.| ).
    ENDIF.
    DATA(factor_record) = factor_records[ 1 ].
    IF factor_record-AlternativeExchangeRateType IS NOT INITIAL.
      RAISE EXCEPTION NEW zcx_exed_ptax( detail = |Tipo alternativo { factor_record-AlternativeExchangeRateType } configurado para M { source_currency }/{ target_currency }; revisar configuracao.| ).
    ENDIF.
    IF pair-quotation = 'I'.
      factors-source_units = factor_record-NumberOfTargetCurrencyUnits.
      factors-target_units = factor_record-NumberOfSourceCurrencyUnits.
    ELSE.
      factors-source_units = factor_record-NumberOfSourceCurrencyUnits.
      factors-target_units = factor_record-NumberOfTargetCurrencyUnits.
    ENDIF.
    IF factors-source_units <= 0 OR factors-target_units <= 0.
      RAISE EXCEPTION NEW zcx_exed_ptax( detail = |Fatores invalidos para M { source_currency }/{ target_currency }.| ).
    ENDIF.
  ENDMETHOD.

  METHOD read_current.
    SELECT SINGLE ExchangeRate
      FROM I_ExchangeRateRawData
      WHERE ExchangeRateType = @zif_exed_ptax_types=>exchange_rate_type
        AND SourceCurrency = @item-source_currency
        AND TargetCurrency = @item-target_currency
        AND ValidityStartDate = @item-effective_date
      INTO @current_rate-signed_rate.
    current_rate-found = xsdbool( sy-subrc = 0 ).
  ENDMETHOD.

  METHOD zif_exed_ptax_rate_store~inspect.
    IF requested_date IS INITIAL.
      RAISE EXCEPTION NEW zcx_exed_ptax( detail = 'Data de cotacao obrigatoria.' ).
    ENDIF.
    DATA seen_keys TYPE HASHED TABLE OF string WITH UNIQUE KEY table_line.
    LOOP AT currency_pairs INTO DATA(pair).
      IF pair-source_currency IS INITIAL OR pair-target_currency IS INITIAL
         OR pair-source_currency = pair-target_currency.
        RAISE EXCEPTION NEW zcx_exed_ptax( detail = 'Par de moedas invalido.' ).
      ENDIF.
      INSERT |{ pair-source_currency }/{ pair-target_currency }| INTO TABLE seen_keys.
      IF sy-subrc <> 0.
        RAISE EXCEPTION NEW zcx_exed_ptax( detail = 'Par de moedas duplicado.' ).
      ENDIF.
      DATA(item) = CORRESPONDING zif_exed_ptax_types=>rate_item( pair ).
      item-effective_date = requested_date.
      DATA(quote_count) = 0.
      DATA quote TYPE zif_exed_ptax_types=>ptax_quote.
      LOOP AT quotes INTO DATA(candidate_quote)
           WHERE currency = pair-bacen_currency AND quotation_date = requested_date.
        quote_count += 1.
        quote = candidate_quote.
      ENDLOOP.
      IF quote_count > 1.
        RAISE EXCEPTION NEW zcx_exed_ptax( detail = 'Cotacao BACEN duplicada na entrada.' ).
      ENDIF.
      IF quote_count = 0 OR quote-found = abap_false.
        item-action = zif_exed_ptax_types=>action_no_bulletin.
        item-message = 'Sem boletim de fechamento na data solicitada.'.
        APPEND item TO result_items.
        CONTINUE.
      ENDIF.
      item-buy_rate = quote-buy_rate.
      DATA(current_factors) = read_factors( pair = pair requested_date = requested_date ).
      item-source_units = current_factors-source_units.
      item-target_units = current_factors-target_units.
      item-absolute_rate = normalize(
        buy_rate = quote-buy_rate quotation = pair-quotation
        factors = current_factors ).
      DATA(current_rate) = read_current( item ).
      item-old_signed_rate = current_rate-signed_rate.
      IF current_rate-found = abap_false.
        item-action = zif_exed_ptax_types=>action_create.
      ELSEIF current_rate-signed_rate = signed_rate(
          absolute_rate = item-absolute_rate quotation = item-quotation ).
        item-action = zif_exed_ptax_types=>action_unchanged.
      ELSE.
        item-action = zif_exed_ptax_types=>action_update.
      ENDIF.
      APPEND item TO result_items.
    ENDLOOP.
  ENDMETHOD.

  METHOD revalidate.
    DATA(current_factors) = read_factors(
      pair = CORRESPONDING #( item ) requested_date = item-effective_date ).
    IF current_factors-source_units <> item-source_units
       OR current_factors-target_units <> item-target_units
       OR normalize( buy_rate = item-buy_rate quotation = item-quotation
                     factors = current_factors ) <> item-absolute_rate.
      RAISE EXCEPTION NEW zcx_exed_ptax( detail = 'Fatores ou cotacao mudaram desde a inspecao;' ).
    ENDIF.
    DATA(current_rate) = read_current( item ).
    IF ( item-action = zif_exed_ptax_types=>action_create AND current_rate-found = abap_true )
       OR ( ( item-action = zif_exed_ptax_types=>action_update
              OR item-action = zif_exed_ptax_types=>action_unchanged )
            AND ( current_rate-found = abap_false OR current_rate-signed_rate <> item-old_signed_rate ) ).
      RAISE EXCEPTION NEW zcx_exed_ptax( detail = |Cambio M { item-source_currency }/{ item-target_currency } alterado concorrentemente; reprocessar.| ).
    ENDIF.
  ENDMETHOD.

  METHOD check_response.
    DATA(has_error) = xsdbool( failed-exchangerate IS NOT INITIAL ).
    DATA message_text TYPE string.
    "FAILED pode informar a causa mesmo quando REPORTED não contém mensagem.
    LOOP AT failed-exchangerate INTO DATA(failed_rate).
      DATA(cause_name) = SWITCH string( failed_rate-%fail-cause
        WHEN if_abap_behv=>cause-not_found THEN 'NOT_FOUND'
        WHEN if_abap_behv=>cause-unauthorized THEN 'UNAUTHORIZED'
        WHEN if_abap_behv=>cause-locked THEN 'LOCKED'
        WHEN if_abap_behv=>cause-conflict THEN 'CONFLICT'
        WHEN if_abap_behv=>cause-disabled THEN 'DISABLED'
        WHEN if_abap_behv=>cause-readonly THEN 'READONLY'
        WHEN if_abap_behv=>cause-dependency THEN 'DEPENDENCY'
        WHEN if_abap_behv=>cause-unspecific THEN 'UNSPECIFIC'
        ELSE 'OUTRA' ).
      message_text = message_text &&
        | FAILED: { cause_name } ({ CONV i( failed_rate-%fail-cause ) }); PID={ failed_rate-%pid }; | &&
        |chave={ failed_rate-ExchangeRateType }/{ failed_rate-SourceCurrency }/{ failed_rate-TargetCurrency }/{ failed_rate-ExchangeRateEffectiveDate DATE = ISO }.|.
    ENDLOOP.
    LOOP AT reported-exchangerate INTO DATA(message).
      IF message-%msg IS BOUND.
        IF message-%msg->m_severity = if_abap_behv_message=>severity-error.
          has_error = abap_true.
        ENDIF.
        message_text = |{ message_text } { message-%msg->if_message~get_text( ) }|.
      ENDIF.
    ENDLOOP.
    LOOP AT reported-%other INTO DATA(other_message).
      IF other_message IS BOUND.
        IF other_message->m_severity = if_abap_behv_message=>severity-error.
          has_error = abap_true.
        ENDIF.
        message_text = |{ message_text } { other_message->if_message~get_text( ) }|.
      ENDIF.
    ENDLOOP.
    IF has_error = abap_true.
      RAISE EXCEPTION NEW zcx_exed_ptax( detail = |{ step }: falha no BOI. { message_text }| ).
    ENDIF.
  ENDMETHOD.

  METHOD build_activation_requests.
    IF lines( keys ) <> 1.
      RAISE EXCEPTION NEW zcx_exed_ptax( detail = 'Ativacao exige exatamente um rascunho.' ).
    ENDIF.
    "Activate usa a chave preliminar: PID + chave, sem o indicador de draft.
    requests = VALUE #( FOR key IN keys
      ( %cid = 'ACTIVATE_PTAX' %pky = key-%pky ) ).
  ENDMETHOD.

  METHOD stage_one.
    "Preparar um par sem commit; o chamador controla a LUW SAP.
    revalidate( item ).
    DATA keys TYPE rate_keys.
    IF item-action = zif_exed_ptax_types=>action_create.
      MODIFY ENTITIES OF I_CurrencyExchangeRateTP_2
        ENTITY ExchangeRate
        CREATE FIELDS ( ExchangeRateTypeForEdit SourceCurrencyForEdit
                        TargetCurrencyForEdit ExchangeRateEffectiveDateFoEd
                        ExchangeRateQuotation AbsoluteExchangeRate )
        WITH VALUE #( ( %cid = 'PTAX' %is_draft = if_abap_behv=>mk-on
          ExchangeRateTypeForEdit = zif_exed_ptax_types=>exchange_rate_type
          SourceCurrencyForEdit = item-source_currency
          TargetCurrencyForEdit = item-target_currency
          ExchangeRateEffectiveDateFoEd = item-effective_date
          ExchangeRateQuotation = item-quotation
          AbsoluteExchangeRate = item-absolute_rate ) )
        MAPPED DATA(mapped) FAILED DATA(failed) REPORTED DATA(reported).
      check_response( failed = failed reported = reported step = 'CREATE draft' ).
      keys = CORRESPONDING #( mapped-exchangerate ).
      IF lines( keys ) <> 1.
        RAISE EXCEPTION NEW zcx_exed_ptax( detail = 'BOI nao devolveu a identidade do draft criado.' ).
      ENDIF.
    ELSEIF item-action = zif_exed_ptax_types=>action_update.
      MODIFY ENTITIES OF I_CurrencyExchangeRateTP_2
        ENTITY ExchangeRate EXECUTE Edit
        FROM VALUE #( ( %cid = 'EDIT_PTAX'
          %key-ExchangeRateType = zif_exed_ptax_types=>exchange_rate_type
          %key-SourceCurrency = item-source_currency
          %key-TargetCurrency = item-target_currency
          %key-ExchangeRateEffectiveDate = item-effective_date
          %param-preserve_changes = abap_true ) )
        FAILED failed REPORTED reported.
      check_response( failed = failed reported = reported step = 'Edit' ).
      keys = VALUE #( ( ExchangeRateType = zif_exed_ptax_types=>exchange_rate_type
        SourceCurrency = item-source_currency TargetCurrency = item-target_currency
        ExchangeRateEffectiveDate = item-effective_date %is_draft = if_abap_behv=>mk-on ) ).
      revalidate( item ).
    ELSE.
      RAISE EXCEPTION NEW zcx_exed_ptax( detail = 'Acao de gravacao invalida.' ).
    ENDIF.
    LOOP AT keys ASSIGNING FIELD-SYMBOL(<key>).
      <key>-%is_draft = if_abap_behv=>mk-on.
    ENDLOOP.
    "Preservar a identidade técnica retornada pelo RAP, incluindo o PID tardio.
    MODIFY ENTITIES OF I_CurrencyExchangeRateTP_2
      ENTITY ExchangeRate UPDATE FIELDS ( ExchangeRateQuotation AbsoluteExchangeRate )
      WITH VALUE #( FOR key IN keys ( %tky = key-%tky
        ExchangeRateQuotation = item-quotation AbsoluteExchangeRate = item-absolute_rate ) )
      FAILED failed REPORTED reported.
    check_response( failed = failed reported = reported step = 'UPDATE draft' ).
    MODIFY ENTITIES OF I_CurrencyExchangeRateTP_2
      ENTITY ExchangeRate EXECUTE Determine FROM CORRESPONDING #( keys )
      FAILED failed REPORTED reported.
    check_response( failed = failed reported = reported step = 'Determine' ).
    READ ENTITIES OF I_CurrencyExchangeRateTP_2
      ENTITY ExchangeRate ALL FIELDS WITH keys
      RESULT DATA(drafts) FAILED failed REPORTED reported.
    check_response( failed = failed reported = reported step = 'READ draft' ).
    IF lines( drafts ) <> 1.
      RAISE EXCEPTION NEW zcx_exed_ptax( detail = 'BOI nao retornou o draft esperado.' ).
    ENDIF.
    DATA(draft) = drafts[ 1 ].
    IF draft-NumberOfSourceCurrencyUnits <> item-source_units
       OR draft-NumberOfTargetCurrencyUnits <> item-target_units
       OR draft-AbsoluteExchangeRate <> item-absolute_rate
       OR draft-ExchangeRateQuotation <> item-quotation.
      RAISE EXCEPTION NEW zcx_exed_ptax( detail = 'Fatores, notacao ou valor derivados divergem' ).
    ENDIF.
    MODIFY ENTITIES OF I_CurrencyExchangeRateTP_2
      ENTITY ExchangeRate EXECUTE Prepare FROM CORRESPONDING #( keys )
      FAILED failed REPORTED reported.
    "Obter mensagens de estado por READ após validar o rascunho.
    READ ENTITIES OF I_CurrencyExchangeRateTP_2
      ENTITY ExchangeRate ALL FIELDS WITH keys
      RESULT DATA(prepared_drafts) FAILED DATA(read_failed) REPORTED DATA(read_reported).
    check_response( failed = read_failed reported = read_reported step = 'Prepare state' ).
    check_response( failed = failed reported = reported step = 'Prepare' ).
    "Prepare bloqueia o registro; comparar novamente o estado persistido sob bloqueio.
    revalidate( item ).
    DATA(requests) = build_activation_requests( keys ).
    MODIFY ENTITIES OF I_CurrencyExchangeRateTP_2
      ENTITY ExchangeRate EXECUTE Activate
      FROM requests
      FAILED failed REPORTED reported.
    check_response( failed = failed reported = reported step = 'Activate' ).
  ENDMETHOD.

  METHOD zif_exed_ptax_rate_store~apply.
    "Limite aprovado: um par por LUW, preservando os pares já concluídos.
    "Este adaptador deve ser chamado pelo job dedicado, fora de um handler RAP.
    result_items = items.
    DATA seen_keys TYPE HASHED TABLE OF string WITH UNIQUE KEY table_line.
    LOOP AT result_items ASSIGNING FIELD-SYMBOL(<item>).
      IF <item>-action = zif_exed_ptax_types=>action_no_bulletin.
        CONTINUE.
      ENDIF.
      DATA(commit_attempted) = abap_false.
      TRY.
          IF <item>-action <> zif_exed_ptax_types=>action_create
             AND <item>-action <> zif_exed_ptax_types=>action_update
             AND <item>-action <> zif_exed_ptax_types=>action_unchanged.
            RAISE EXCEPTION NEW zcx_exed_ptax( detail = 'Acao de gravacao invalida.' ).
          ENDIF.
          INSERT |{ <item>-source_currency }/{ <item>-target_currency }/{ <item>-effective_date }|
            INTO TABLE seen_keys.
          IF sy-subrc <> 0.
            RAISE EXCEPTION NEW zcx_exed_ptax( detail = 'Par/data duplicado na gravacao.' ).
          ENDIF.
          IF <item>-action = zif_exed_ptax_types=>action_unchanged.
            revalidate( <item> ).
            <item>-message = 'Taxa e fatores revalidados; sem alteracao ou COMMIT.'.
            CONTINUE.
          ENDIF.
          stage_one( <item> ).
          commit_attempted = abap_true.
          COMMIT ENTITIES RESPONSE OF I_CurrencyExchangeRateTP_2
            FAILED DATA(save_failed) REPORTED DATA(save_reported).
          DATA(commit_result) = sy-subrc.
          check_response(
            failed = CORRESPONDING #( DEEP save_failed )
            reported = CORRESPONDING #( DEEP save_reported )
            step = 'COMMIT ENTITIES' ).
          IF commit_result <> 0.
            RAISE EXCEPTION NEW zcx_exed_ptax( detail = |COMMIT ENTITIES retornou { commit_result }.| ).
          ENDIF.
          DATA(saved_rate) = read_current( <item> ).
          IF saved_rate-found = abap_false OR saved_rate-signed_rate <> signed_rate(
              absolute_rate = <item>-absolute_rate quotation = <item>-quotation ).
            RAISE EXCEPTION NEW zcx_exed_ptax( detail = 'Leitura apos COMMIT nao confirmou a taxa esperada.' ).
          ENDIF.
          <item>-message = 'Gravacao confirmada por leitura apos COMMIT do par.'.
        CATCH cx_root INTO DATA(pair_error).
          <item>-action = zif_exed_ptax_types=>action_error.
          IF pair_error IS INSTANCE OF zcx_exed_ptax.
            <item>-message = CAST zcx_exed_ptax( pair_error )->detail.
          ELSE.
            <item>-message = pair_error->get_text( ).
          ENDIF.
          "Limpar o buffer atual; isso não desfaz um commit já concluído.
          ROLLBACK ENTITIES.
          IF commit_attempted = abap_true.
            TRY.
                DATA(actual_rate) = read_current( <item> ).
                IF actual_rate-found = abap_false.
                  <item>-message = |{ <item>-message } Reconciliacao: chave ausente.|.
                ELSE.
                  <item>-message = |{ <item>-message } Reconciliacao: taxa persistida { actual_rate-signed_rate }.|.
                ENDIF.
              CATCH cx_root INTO DATA(reconciliation_error).
                <item>-message = |{ <item>-message } Reconciliacao indisponivel: { reconciliation_error->get_text( ) }.|.
            ENDTRY.
            <item>-message = |{ <item>-message } COMMIT foi tentado; revisar resultado antes de reprocessar. Sem repeticao automatica.|.
          ELSE.
            <item>-message = |{ <item>-message } Alteracoes do par descartadas antes do COMMIT.|.
          ENDIF.
      ENDTRY.
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.
