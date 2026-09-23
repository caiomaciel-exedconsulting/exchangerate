CLASS zcl_exed_ptax_rate_store DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES zif_exed_ptax_rate_store.
  PRIVATE SECTION.
    TYPES:
      BEGIN OF ty_factors,
        source_units TYPE decfloat34,
        target_units TYPE decfloat34,
      END OF ty_factors,
      BEGIN OF ty_current,
        found TYPE abap_bool,
        signed_rate TYPE zif_exed_ptax_types=>ty_rate,
      END OF ty_current.
    TYPES ty_failed TYPE RESPONSE FOR FAILED EARLY i_currencyexchangeratetp_2.
    TYPES ty_reported TYPE RESPONSE FOR REPORTED EARLY i_currencyexchangeratetp_2.
    TYPES tt_keys TYPE TABLE FOR READ IMPORT i_currencyexchangeratetp_2.
    CLASS-METHODS normalize
      IMPORTING iv_buy_rate TYPE decfloat34
                iv_quotation TYPE zif_exed_ptax_types=>ty_quotation
                is_factors TYPE ty_factors
      RETURNING VALUE(rv_rate) TYPE zif_exed_ptax_types=>ty_rate
      RAISING zcx_exed_ptax.
    CLASS-METHODS signed_rate
      IMPORTING iv_absolute TYPE zif_exed_ptax_types=>ty_rate
                iv_quotation TYPE zif_exed_ptax_types=>ty_quotation
      RETURNING VALUE(rv_rate) TYPE zif_exed_ptax_types=>ty_rate
      RAISING zcx_exed_ptax.
    METHODS read_factors
      IMPORTING is_pair TYPE zif_exed_ptax_types=>ty_pair iv_date TYPE d
      RETURNING VALUE(rs_factors) TYPE ty_factors
      RAISING zcx_exed_ptax.
    METHODS read_current
      IMPORTING is_item TYPE zif_exed_ptax_types=>ty_item
      RETURNING VALUE(rs_current) TYPE ty_current.
    METHODS revalidate
      IMPORTING is_item TYPE zif_exed_ptax_types=>ty_item
      RAISING zcx_exed_ptax.
    METHODS check_response
      IMPORTING is_failed TYPE ty_failed is_reported TYPE ty_reported
                iv_step TYPE string
      RAISING zcx_exed_ptax.
    METHODS stage_one
      IMPORTING is_item TYPE zif_exed_ptax_types=>ty_item
      RAISING zcx_exed_ptax.
ENDCLASS.

CLASS zcl_exed_ptax_rate_store IMPLEMENTATION.
  METHOD normalize.
    IF iv_buy_rate <= 0 OR is_factors-source_units <= 0
       OR is_factors-target_units <= 0.
      RAISE EXCEPTION NEW zcx_exed_ptax(
        detail = 'Cotacao e fatores de conversao devem ser positivos.' ).
    ENDIF.
    TRY.
        DATA lv_value TYPE decfloat34.
        CASE iv_quotation.
          WHEN 'D'.
            lv_value = iv_buy_rate * is_factors-source_units / is_factors-target_units.
          WHEN 'I'.
            lv_value = iv_buy_rate * is_factors-target_units / is_factors-source_units.
          WHEN OTHERS.
            RAISE EXCEPTION NEW zcx_exed_ptax( detail = 'Notacao deve ser D ou I.' ).
        ENDCASE.
        "The released BO field defines precision and rounding for comparison/save.
        rv_rate = CONV #( lv_value ).
      CATCH cx_sy_arithmetic_error cx_sy_conversion_error INTO DATA(lx_numeric).
        RAISE EXCEPTION NEW zcx_exed_ptax(
          detail = 'Cotacao excede a representacao do campo de cambio SAP.'
          previous = lx_numeric ).
    ENDTRY.
    IF rv_rate <= 0.
      RAISE EXCEPTION NEW zcx_exed_ptax(
        detail = 'Cotacao ficou zero apos arredondamento na precisao SAP.' ).
    ENDIF.
  ENDMETHOD.

  METHOD signed_rate.
    CASE iv_quotation.
      WHEN 'D'. rv_rate = iv_absolute.
      WHEN 'I'. rv_rate = - iv_absolute.
      WHEN OTHERS.
        RAISE EXCEPTION NEW zcx_exed_ptax( detail = 'Notacao deve ser D ou I.' ).
    ENDCASE.
  ENDMETHOD.

  METHOD read_factors.
    DATA(lv_source) = is_pair-source_currency.
    DATA(lv_target) = is_pair-target_currency.
    IF is_pair-quotation = 'I'.
      "The BO resolves indirect factors using the opposite currency pair.
      lv_source = is_pair-target_currency.
      lv_target = is_pair-source_currency.
    ELSEIF is_pair-quotation <> 'D'.
      RAISE EXCEPTION NEW zcx_exed_ptax( detail = 'Notacao deve ser D ou I.' ).
    ENDIF.
    SELECT NumberOfSourceCurrencyUnits, NumberOfTargetCurrencyUnits,
           AlternativeExchangeRateType, AltvExchangeRateTypeValdtyDate
      FROM I_ExchangeRateFactorsRawData
      WHERE ExchangeRateType = @zif_exed_ptax_types=>exchange_rate_type
        AND SourceCurrency = @lv_source AND TargetCurrency = @lv_target
        AND ValidityStartDate <= @iv_date
      ORDER BY ValidityStartDate DESCENDING
      INTO TABLE @DATA(lt_factors)
      UP TO 1 ROWS.
    IF lt_factors IS INITIAL.
      RAISE EXCEPTION NEW zcx_exed_ptax(
        detail = |Sem fatores M { lv_source }/{ lv_target } validos em { iv_date DATE = ISO }.| ).
    ENDIF.
    DATA(ls_factor) = lt_factors[ 1 ].
    IF ls_factor-AlternativeExchangeRateType IS NOT INITIAL.
      RAISE EXCEPTION NEW zcx_exed_ptax(
        detail = |Tipo alternativo { ls_factor-AlternativeExchangeRateType } configurado para M { lv_source }/{ lv_target }; revisar configuracao.| ).
    ENDIF.
    IF is_pair-quotation = 'I'.
      rs_factors-source_units = ls_factor-NumberOfTargetCurrencyUnits.
      rs_factors-target_units = ls_factor-NumberOfSourceCurrencyUnits.
    ELSE.
      rs_factors-source_units = ls_factor-NumberOfSourceCurrencyUnits.
      rs_factors-target_units = ls_factor-NumberOfTargetCurrencyUnits.
    ENDIF.
    IF rs_factors-source_units <= 0 OR rs_factors-target_units <= 0.
      RAISE EXCEPTION NEW zcx_exed_ptax(
        detail = |Fatores invalidos para M { lv_source }/{ lv_target }.| ).
    ENDIF.
  ENDMETHOD.

  METHOD read_current.
    SELECT SINGLE ExchangeRate
      FROM I_ExchangeRateRawData
      WHERE ExchangeRateType = @zif_exed_ptax_types=>exchange_rate_type
        AND SourceCurrency = @is_item-source_currency
        AND TargetCurrency = @is_item-target_currency
        AND ValidityStartDate = @is_item-effective_date
      INTO @rs_current-signed_rate.
    rs_current-found = xsdbool( sy-subrc = 0 ).
  ENDMETHOD.

  METHOD zif_exed_ptax_rate_store~inspect.
    IF iv_date IS INITIAL.
      RAISE EXCEPTION NEW zcx_exed_ptax( detail = 'Data de cotacao obrigatoria.' ).
    ENDIF.
    DATA lt_seen TYPE HASHED TABLE OF string WITH UNIQUE KEY table_line.
    LOOP AT it_pairs INTO DATA(ls_pair).
      IF ls_pair-source_currency IS INITIAL OR ls_pair-target_currency IS INITIAL
         OR ls_pair-source_currency = ls_pair-target_currency.
        RAISE EXCEPTION NEW zcx_exed_ptax( detail = 'Par de moedas invalido.' ).
      ENDIF.
      INSERT |{ ls_pair-source_currency }/{ ls_pair-target_currency }| INTO TABLE lt_seen.
      IF sy-subrc <> 0.
        RAISE EXCEPTION NEW zcx_exed_ptax( detail = 'Par de moedas duplicado.' ).
      ENDIF.
      DATA(ls_item) = CORRESPONDING zif_exed_ptax_types=>ty_item( ls_pair ).
      ls_item-effective_date = iv_date.
      DATA(lv_quote_count) = 0.
      DATA ls_quote TYPE zif_exed_ptax_types=>ty_quote.
      LOOP AT it_quotes INTO DATA(ls_candidate)
           WHERE currency = ls_pair-bacen_currency AND quotation_date = iv_date.
        lv_quote_count += 1.
        ls_quote = ls_candidate.
      ENDLOOP.
      IF lv_quote_count > 1.
        RAISE EXCEPTION NEW zcx_exed_ptax( detail = 'Cotacao BACEN duplicada na entrada.' ).
      ENDIF.
      IF lv_quote_count = 0 OR ls_quote-found = abap_false.
        ls_item-action = zif_exed_ptax_types=>action_no_bulletin.
        ls_item-message = 'Sem boletim de fechamento na data solicitada.'.
        APPEND ls_item TO rt_items.
        CONTINUE.
      ENDIF.
      ls_item-buy_rate = ls_quote-buy_rate.
      DATA(ls_factors) = read_factors( is_pair = ls_pair iv_date = iv_date ).
      ls_item-source_units = ls_factors-source_units.
      ls_item-target_units = ls_factors-target_units.
      ls_item-absolute_rate = normalize(
        iv_buy_rate = ls_quote-buy_rate iv_quotation = ls_pair-quotation
        is_factors = ls_factors ).
      DATA(ls_current) = read_current( ls_item ).
      ls_item-old_signed_rate = ls_current-signed_rate.
      IF ls_current-found = abap_false.
        ls_item-action = zif_exed_ptax_types=>action_create.
      ELSEIF ls_current-signed_rate = signed_rate(
          iv_absolute = ls_item-absolute_rate iv_quotation = ls_item-quotation ).
        ls_item-action = zif_exed_ptax_types=>action_unchanged.
      ELSE.
        ls_item-action = zif_exed_ptax_types=>action_update.
      ENDIF.
      APPEND ls_item TO rt_items.
    ENDLOOP.
  ENDMETHOD.

  METHOD revalidate.
    DATA(ls_factors) = read_factors(
      is_pair = CORRESPONDING #( is_item ) iv_date = is_item-effective_date ).
    IF ls_factors-source_units <> is_item-source_units
       OR ls_factors-target_units <> is_item-target_units
       OR normalize( iv_buy_rate = is_item-buy_rate iv_quotation = is_item-quotation
                     is_factors = ls_factors ) <> is_item-absolute_rate.
      RAISE EXCEPTION NEW zcx_exed_ptax(
        detail = 'Fatores ou cotacao mudaram desde a inspecao; reprocessar.' ).
    ENDIF.
    DATA(ls_current) = read_current( is_item ).
    IF ( is_item-action = zif_exed_ptax_types=>action_create AND ls_current-found = abap_true )
       OR ( ( is_item-action = zif_exed_ptax_types=>action_update
              OR is_item-action = zif_exed_ptax_types=>action_unchanged )
            AND ( ls_current-found = abap_false OR ls_current-signed_rate <> is_item-old_signed_rate ) ).
      RAISE EXCEPTION NEW zcx_exed_ptax(
        detail = |Cambio M { is_item-source_currency }/{ is_item-target_currency } alterado concorrentemente; reprocessar.| ).
    ENDIF.
  ENDMETHOD.

  METHOD check_response.
    DATA(lv_error) = xsdbool( is_failed-exchangerate IS NOT INITIAL ).
    DATA lv_text TYPE string.
    LOOP AT is_reported-exchangerate INTO DATA(ls_message).
      IF ls_message-%msg IS BOUND.
        IF ls_message-%msg->m_severity = if_abap_behv_message=>severity-error.
          lv_error = abap_true.
        ENDIF.
        lv_text = |{ lv_text } { ls_message-%msg->if_message~get_text( ) }|.
      ENDIF.
    ENDLOOP.
    LOOP AT is_reported-%other INTO DATA(lo_other).
      IF lo_other IS BOUND.
        IF lo_other->m_severity = if_abap_behv_message=>severity-error.
          lv_error = abap_true.
        ENDIF.
        lv_text = |{ lv_text } { lo_other->if_message~get_text( ) }|.
      ENDIF.
    ENDLOOP.
    IF lv_error = abap_true.
      RAISE EXCEPTION NEW zcx_exed_ptax( detail = |{ iv_step }: falha no BOI. { lv_text }| ).
    ENDIF.
  ENDMETHOD.

  METHOD stage_one.
    "One pair is staged without committing. The caller owns the SAP LUW.
    revalidate( is_item ).
    DATA lt_keys TYPE tt_keys.
    IF is_item-action = zif_exed_ptax_types=>action_create.
      MODIFY ENTITIES OF I_CurrencyExchangeRateTP_2
        ENTITY ExchangeRate
        CREATE FIELDS ( ExchangeRateTypeForEdit SourceCurrencyForEdit
                        TargetCurrencyForEdit ExchangeRateEffectiveDateFoEd
                        ExchangeRateQuotation AbsoluteExchangeRate )
        WITH VALUE #( ( %cid = 'PTAX' %is_draft = if_abap_behv=>mk-on
          ExchangeRateTypeForEdit = zif_exed_ptax_types=>exchange_rate_type
          SourceCurrencyForEdit = is_item-source_currency
          TargetCurrencyForEdit = is_item-target_currency
          ExchangeRateEffectiveDateFoEd = is_item-effective_date
          ExchangeRateQuotation = is_item-quotation
          AbsoluteExchangeRate = is_item-absolute_rate ) )
        MAPPED DATA(ls_mapped) FAILED DATA(ls_failed) REPORTED DATA(ls_reported).
      check_response( is_failed = ls_failed is_reported = ls_reported iv_step = 'CREATE draft' ).
      lt_keys = CORRESPONDING #( ls_mapped-exchangerate ).
      IF lines( lt_keys ) <> 1.
        RAISE EXCEPTION NEW zcx_exed_ptax( detail = 'BOI nao devolveu a identidade do draft criado.' ).
      ENDIF.
    ELSEIF is_item-action = zif_exed_ptax_types=>action_update.
      MODIFY ENTITIES OF I_CurrencyExchangeRateTP_2
        ENTITY ExchangeRate EXECUTE Edit
        FROM VALUE #( ( %cid = 'EDIT_PTAX'
          %key-ExchangeRateType = zif_exed_ptax_types=>exchange_rate_type
          %key-SourceCurrency = is_item-source_currency
          %key-TargetCurrency = is_item-target_currency
          %key-ExchangeRateEffectiveDate = is_item-effective_date
          %is_draft = if_abap_behv=>mk-off %param-preserve_changes = abap_true ) )
        FAILED ls_failed REPORTED ls_reported.
      check_response( is_failed = ls_failed is_reported = ls_reported iv_step = 'Edit' ).
      lt_keys = VALUE #( ( ExchangeRateType = zif_exed_ptax_types=>exchange_rate_type
        SourceCurrency = is_item-source_currency TargetCurrency = is_item-target_currency
        ExchangeRateEffectiveDate = is_item-effective_date %is_draft = if_abap_behv=>mk-on ) ).
      revalidate( is_item ).
    ELSE.
      RAISE EXCEPTION NEW zcx_exed_ptax( detail = 'Acao de gravacao invalida.' ).
    ENDIF.
    LOOP AT lt_keys ASSIGNING FIELD-SYMBOL(<ls_key>).
      <ls_key>-%is_draft = if_abap_behv=>mk-on.
    ENDLOOP.
    "Keep the technical identity returned by RAP, including the late-numbering PID.
    MODIFY ENTITIES OF I_CurrencyExchangeRateTP_2
      ENTITY ExchangeRate UPDATE FIELDS ( ExchangeRateQuotation AbsoluteExchangeRate )
      WITH VALUE #( FOR ls_key IN lt_keys ( %tky = ls_key-%tky
        ExchangeRateQuotation = is_item-quotation AbsoluteExchangeRate = is_item-absolute_rate ) )
      FAILED ls_failed REPORTED ls_reported.
    check_response( is_failed = ls_failed is_reported = ls_reported iv_step = 'UPDATE draft' ).
    MODIFY ENTITIES OF I_CurrencyExchangeRateTP_2
      ENTITY ExchangeRate EXECUTE Determine FROM CORRESPONDING #( lt_keys )
      FAILED ls_failed REPORTED ls_reported.
    check_response( is_failed = ls_failed is_reported = ls_reported iv_step = 'Determine' ).
    READ ENTITIES OF I_CurrencyExchangeRateTP_2
      ENTITY ExchangeRate ALL FIELDS WITH lt_keys
      RESULT DATA(lt_draft) FAILED ls_failed REPORTED ls_reported.
    check_response( is_failed = ls_failed is_reported = ls_reported iv_step = 'READ draft' ).
    IF lines( lt_draft ) <> 1.
      RAISE EXCEPTION NEW zcx_exed_ptax( detail = 'BOI nao retornou o draft esperado.' ).
    ENDIF.
    DATA(ls_draft) = lt_draft[ 1 ].
    IF ls_draft-NumberOfSourceCurrencyUnits <> is_item-source_units
       OR ls_draft-NumberOfTargetCurrencyUnits <> is_item-target_units
       OR ls_draft-AbsoluteExchangeRate <> is_item-absolute_rate
       OR ls_draft-ExchangeRateQuotation <> is_item-quotation.
      RAISE EXCEPTION NEW zcx_exed_ptax(
        detail = 'Fatores, notacao ou valor derivados pelo BOI divergem da inspecao.' ).
    ENDIF.
    MODIFY ENTITIES OF I_CurrencyExchangeRateTP_2
      ENTITY ExchangeRate EXECUTE Prepare FROM CORRESPONDING #( lt_keys )
      FAILED ls_failed REPORTED ls_reported.
    "State messages are obtained by READ after draft validation.
    READ ENTITIES OF I_CurrencyExchangeRateTP_2
      ENTITY ExchangeRate ALL FIELDS WITH lt_keys
      RESULT DATA(lt_prepared) FAILED DATA(ls_read_failed) REPORTED DATA(ls_read_reported).
    check_response( is_failed = ls_read_failed is_reported = ls_read_reported iv_step = 'Prepare state' ).
    check_response( is_failed = ls_failed is_reported = ls_reported iv_step = 'Prepare' ).
    "Prepare obtains the business lock; compare the persisted snapshot again under it.
    revalidate( is_item ).
    MODIFY ENTITIES OF I_CurrencyExchangeRateTP_2
      ENTITY ExchangeRate EXECUTE Activate
      FROM VALUE #( FOR ls_activate_key IN lt_keys
        ( %cid = 'ACTIVATE_PTAX' %tky = ls_activate_key-%tky ) )
      FAILED ls_failed REPORTED ls_reported.
    check_response( is_failed = ls_failed is_reported = ls_reported iv_step = 'Activate' ).
  ENDMETHOD.

  METHOD zif_exed_ptax_rate_store~apply.
    "Approved transaction boundary: one pair per LUW, preserving previous successes.
    "This adapter must be called by the dedicated job, outside a RAP handler.
    rt_items = it_items.
    DATA lt_seen TYPE HASHED TABLE OF string WITH UNIQUE KEY table_line.
    LOOP AT rt_items ASSIGNING FIELD-SYMBOL(<ls_item>).
      IF <ls_item>-action = zif_exed_ptax_types=>action_no_bulletin.
        CONTINUE.
      ENDIF.
      DATA(lv_commit_attempted) = abap_false.
      TRY.
          IF <ls_item>-action <> zif_exed_ptax_types=>action_create
             AND <ls_item>-action <> zif_exed_ptax_types=>action_update
             AND <ls_item>-action <> zif_exed_ptax_types=>action_unchanged.
            RAISE EXCEPTION NEW zcx_exed_ptax( detail = 'Acao de gravacao invalida.' ).
          ENDIF.
          INSERT |{ <ls_item>-source_currency }/{ <ls_item>-target_currency }/{ <ls_item>-effective_date }|
            INTO TABLE lt_seen.
          IF sy-subrc <> 0.
            RAISE EXCEPTION NEW zcx_exed_ptax( detail = 'Par/data duplicado na gravacao.' ).
          ENDIF.
          IF <ls_item>-action = zif_exed_ptax_types=>action_unchanged.
            revalidate( <ls_item> ).
            <ls_item>-message = 'Taxa e fatores revalidados; sem alteracao ou COMMIT.'.
            CONTINUE.
          ENDIF.
          stage_one( <ls_item> ).
          lv_commit_attempted = abap_true.
          COMMIT ENTITIES RESPONSE OF I_CurrencyExchangeRateTP_2
            FAILED DATA(ls_late_failed) REPORTED DATA(ls_late_reported).
          DATA(lv_commit_subrc) = sy-subrc.
          check_response(
            is_failed = CORRESPONDING #( DEEP ls_late_failed )
            is_reported = CORRESPONDING #( DEEP ls_late_reported )
            iv_step = 'COMMIT ENTITIES' ).
          IF lv_commit_subrc <> 0.
            RAISE EXCEPTION NEW zcx_exed_ptax(
              detail = |COMMIT ENTITIES retornou { lv_commit_subrc }.| ).
          ENDIF.
          DATA(ls_saved) = read_current( <ls_item> ).
          IF ls_saved-found = abap_false OR ls_saved-signed_rate <> signed_rate(
              iv_absolute = <ls_item>-absolute_rate iv_quotation = <ls_item>-quotation ).
            RAISE EXCEPTION NEW zcx_exed_ptax(
              detail = 'Leitura apos COMMIT nao confirmou a taxa esperada.' ).
          ENDIF.
          <ls_item>-message = 'Gravacao confirmada por leitura apos COMMIT do par.'.
        CATCH cx_root INTO DATA(lx_pair).
          <ls_item>-action = zif_exed_ptax_types=>action_error.
          IF lx_pair IS INSTANCE OF zcx_exed_ptax.
            <ls_item>-message = CAST zcx_exed_ptax( lx_pair )->detail.
          ELSE.
            <ls_item>-message = lx_pair->get_text( ).
          ENDIF.
          "Resets the current buffer; it cannot undo a previously completed commit.
          ROLLBACK ENTITIES.
          IF lv_commit_attempted = abap_true.
            TRY.
                DATA(ls_actual) = read_current( <ls_item> ).
                IF ls_actual-found = abap_false.
                  <ls_item>-message = |{ <ls_item>-message } Reconciliacao: chave ausente.|.
                ELSE.
                  <ls_item>-message = |{ <ls_item>-message } Reconciliacao: taxa persistida { ls_actual-signed_rate }.|.
                ENDIF.
              CATCH cx_root INTO DATA(lx_reconcile).
                <ls_item>-message = |{ <ls_item>-message } Reconciliacao indisponivel: { lx_reconcile->get_text( ) }.|.
            ENDTRY.
            <ls_item>-message = |{ <ls_item>-message } COMMIT foi tentado; revisar resultado antes de reprocessar. Sem repeticao automatica.|.
          ELSE.
            <ls_item>-message = |{ <ls_item>-message } Alteracoes do par descartadas antes do COMMIT.|.
          ENDIF.
      ENDTRY.
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.
