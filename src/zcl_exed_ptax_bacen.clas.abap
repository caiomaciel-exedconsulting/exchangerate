CLASS zcl_exed_ptax_bacen DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES zif_exed_ptax_source.
    INTERFACES if_xco_json_tree_visitor.
    METHODS constructor IMPORTING iv_comm_system TYPE string OPTIONAL.
  PRIVATE SECTION.
    TYPES:
      BEGIN OF ty_bulletin,
        buy_rate TYPE decfloat34,
        timestamp TYPE string,
        bulletin_type TYPE string,
        buy_seen TYPE abap_bool,
        timestamp_seen TYPE abap_bool,
        type_seen TYPE abap_bool,
      END OF ty_bulletin,
      tt_bulletins TYPE STANDARD TABLE OF ty_bulletin WITH EMPTY KEY.
    CONSTANTS max_attempts TYPE i VALUE 2.
    CONSTANTS timeout_seconds TYPE i VALUE 20.
    DATA mv_comm_system TYPE string.
    DATA mv_depth TYPE i.
    DATA mv_member TYPE string.
    DATA mv_root_object TYPE abap_bool.
    DATA mv_value_count TYPE i.
    DATA mv_value_array TYPE abap_bool.
    DATA mv_in_value TYPE abap_bool.
    DATA mv_json_error TYPE string.
    DATA mt_bulletins TYPE tt_bulletins.
    METHODS build_query
      IMPORTING iv_currency TYPE zif_exed_ptax_types=>ty_bacen_currency iv_date TYPE d
      RETURNING VALUE(rv_query) TYPE string RAISING zcx_exed_ptax.
    METHODS parse_response
      IMPORTING iv_json TYPE string
                iv_currency TYPE zif_exed_ptax_types=>ty_bacen_currency iv_date TYPE d
      RETURNING VALUE(rs_quote) TYPE zif_exed_ptax_types=>ty_quote
      RAISING zcx_exed_ptax.
    METHODS check_json_value IMPORTING iv_kind TYPE c.
    METHODS close_client
      IMPORTING io_client TYPE REF TO if_web_http_client
      RETURNING VALUE(rv_error) TYPE string.
ENDCLASS.

CLASS zcl_exed_ptax_bacen IMPLEMENTATION.
  METHOD constructor.
    mv_comm_system = iv_comm_system.
  ENDMETHOD.

  METHOD build_query.
    IF iv_currency <> 'USD' AND iv_currency <> 'EUR' AND iv_currency <> 'GBP'
       AND iv_currency <> 'CHF' AND iv_currency <> 'AUD'.
      RAISE EXCEPTION NEW zcx_exed_ptax( detail = |Unsupported BACEN currency { iv_currency }| ).
    ENDIF.
    TRY.
        cl_abap_datfm=>conv_date_ext_to_int(
          EXPORTING im_datext = |{ iv_date+0(4) }-{ iv_date+4(2) }-{ iv_date+6(2) }|
                    im_datfmdes = '6'
          IMPORTING ex_datint = DATA(lv_checked_date) ).
      CATCH cx_abap_datfm_no_date cx_abap_datfm_invalid_date
            cx_abap_datfm_format_unknown cx_abap_datfm_ambiguous INTO DATA(lx_date).
        RAISE EXCEPTION NEW zcx_exed_ptax( detail = 'Invalid BACEN quotation date' previous = lx_date ).
    ENDTRY.
    IF lv_checked_date IS INITIAL.
      RAISE EXCEPTION NEW zcx_exed_ptax( detail = 'BACEN quotation date is required' ).
    ENDIF.
    " Only allowlisted currency and validated numeric date enter this fixed query.
    " Two records suffice to detect unexpected duplicate closing bulletins.
    rv_query = |@moeda='{ iv_currency }'&@dataCotacao='{ iv_date+4(2) }-{ iv_date+6(2) }-{ iv_date+0(4) }'|
      && |&$filter=tipoBoletim%20eq%20'Fechamento%20PTAX'&$format=json&$top=2|
      && |&$select=cotacaoCompra,cotacaoVenda,dataHoraCotacao,tipoBoletim|.
  ENDMETHOD.

  METHOD zif_exed_ptax_source~get_quote.
    DATA(lv_query) = build_query( iv_currency = iv_currency iv_date = iv_date ).
    DATA lo_client TYPE REF TO if_web_http_client.
    DATA lv_close_error TYPE string.
    DO max_attempts TIMES.
      DATA(lv_attempt) = sy-index.
      CLEAR lo_client.
      TRY.
          DATA lo_destination TYPE REF TO if_http_destination.
          IF mv_comm_system IS INITIAL.
            lo_destination = cl_http_destination_provider=>create_by_comm_arrangement(
              comm_scenario = 'ZEXED_PTAX_COMM' service_id = 'ZEXED_PTAX_REST' ).
          ELSE.
            lo_destination = cl_http_destination_provider=>create_by_comm_arrangement(
              comm_scenario = 'ZEXED_PTAX_COMM' service_id = 'ZEXED_PTAX_REST'
              comm_system_id = CONV #( mv_comm_system ) ).
          ENDIF.
          lo_client = cl_web_http_client_manager=>create_by_http_destination( lo_destination ).
          lo_client->enable_path_prefix( ).
          lo_client->set_redirect_policy( abap_false ).
          DATA(lo_request) = lo_client->get_http_request( ).
          lo_request->set_uri_path( '/CotacaoMoedaDia(moeda=@moeda,dataCotacao=@dataCotacao)' ).
          lo_request->set_query( lv_query ).
          lo_request->set_header_field( i_name = 'Accept' i_value = 'application/json' ).
          DATA(lo_response) = lo_client->execute(
            i_method = if_web_http_client=>get i_timeout = timeout_seconds ).
          DATA(ls_status) = lo_response->get_status( ).
          DATA(lv_retry_after) = lo_response->get_header_field( 'Retry-After' ).
          IF ls_status-code <> 200.
            lv_close_error = close_client( lo_client ).
            CLEAR lo_client.
            " Never bypass a server Retry-After, and never WAIT (implicit commit).
            " A job retry/reprocessing is required for 429/503 or Retry-After.
            IF lv_attempt < max_attempts AND lv_retry_after IS INITIAL
               AND lv_close_error IS INITIAL
               AND ( ls_status-code = 502 OR ls_status-code = 504 ).
              CONTINUE.
            ENDIF.
            RAISE EXCEPTION NEW zcx_exed_ptax(
              detail = |BACEN HTTP { ls_status-code } for { iv_currency }/{ iv_date DATE = ISO }; |
                && |attempt { lv_attempt }; Retry-After={ lv_retry_after }; close={ lv_close_error }| ).
          ENDIF.
          DATA(lv_body) = lo_response->get_text( ).
          lv_close_error = close_client( lo_client ).
          CLEAR lo_client.
          IF lv_close_error IS NOT INITIAL.
            RAISE EXCEPTION NEW zcx_exed_ptax( detail = lv_close_error ).
          ENDIF.
          rs_quote = parse_response( iv_json = lv_body iv_currency = iv_currency iv_date = iv_date ).
          RETURN.
        CATCH cx_web_http_client_error INTO DATA(lx_transport).
          lv_close_error = close_client( lo_client ).
          CLEAR lo_client.
          IF lv_attempt < max_attempts AND lv_close_error IS INITIAL.
            CONTINUE.
          ENDIF.
          RAISE EXCEPTION NEW zcx_exed_ptax(
            detail = |BACEN transport failure for { iv_currency }/{ iv_date DATE = ISO }; |
              && |attempt { lv_attempt }; close={ lv_close_error }|
            previous = lx_transport ).
        CATCH cx_http_dest_provider_error cx_web_message_error INTO DATA(lx_http).
          lv_close_error = close_client( lo_client ).
          CLEAR lo_client.
          RAISE EXCEPTION NEW zcx_exed_ptax(
            detail = |BACEN communication configuration/message failure; close={ lv_close_error }|
            previous = lx_http ).
        CATCH zcx_exed_ptax INTO DATA(lx_ptax).
          lv_close_error = close_client( lo_client ).
          IF lv_close_error IS NOT INITIAL.
            RAISE EXCEPTION NEW zcx_exed_ptax(
              detail = |{ lx_ptax->detail }; { lv_close_error }| previous = lx_ptax ).
          ENDIF.
          RAISE EXCEPTION lx_ptax.
        CATCH cx_root INTO DATA(lx_unexpected).
          lv_close_error = close_client( lo_client ).
          RAISE EXCEPTION NEW zcx_exed_ptax(
            detail = |Unexpected BACEN client failure; close={ lv_close_error }|
            previous = lx_unexpected ).
      ENDTRY.
    ENDDO.
    RAISE EXCEPTION NEW zcx_exed_ptax( detail = 'BACEN retry limit reached' ).
  ENDMETHOD.

  METHOD close_client.
    IF io_client IS NOT BOUND.
      RETURN.
    ENDIF.
    TRY.
        io_client->close( ).
      CATCH cx_web_http_client_error INTO DATA(lx_close).
        rv_error = |HTTP client close failed: { lx_close->get_text( ) }|.
    ENDTRY.
  ENDMETHOD.

  METHOD parse_response.
    " Reset even if a parser rejects/ignores input before visitor on_start.
    me->if_xco_json_tree_visitor~on_start( ).
    rs_quote = VALUE #( currency = iv_currency quotation_date = iv_date found = abap_false ).
    IF iv_json IS INITIAL OR strlen( iv_json ) > 32768.
      RAISE EXCEPTION NEW zcx_exed_ptax( detail = 'BACEN JSON body is empty or exceeds 32768 characters' ).
    ENDIF.
    TRY.
        DATA(lo_json) = xco_cp_json=>data->from_string( iv_json ).
        lo_json->traverse( me ).
      CATCH cx_root INTO DATA(lx_json).
        RAISE EXCEPTION NEW zcx_exed_ptax( detail = 'Invalid BACEN JSON' previous = lx_json ).
    ENDTRY.
    IF mv_root_object = abap_false OR mv_value_count <> 1 OR mv_value_array = abap_false
       OR mv_depth <> 0 OR mv_json_error IS NOT INITIAL.
      RAISE EXCEPTION NEW zcx_exed_ptax( detail = |Invalid BACEN JSON contract: { mv_json_error }| ).
    ENDIF.
    IF mt_bulletins IS INITIAL.
      RETURN.
    ENDIF.
    IF lines( mt_bulletins ) <> 1.
      RAISE EXCEPTION NEW zcx_exed_ptax( detail = 'BACEN returned multiple closing bulletins for one currency/date' ).
    ENDIF.
    DATA(ls_bulletin) = mt_bulletins[ 1 ].
    DATA(lv_expected_date) = |{ iv_date+0(4) }-{ iv_date+4(2) }-{ iv_date+6(2) }|.
    IF ls_bulletin-buy_rate <= 0 OR ls_bulletin-bulletin_type <> 'Fechamento PTAX'.
      RAISE EXCEPTION NEW zcx_exed_ptax( detail = 'BACEN closing bulletin or positive purchase rate is invalid' ).
    ENDIF.
    IF NOT matches( val = ls_bulletin-timestamp
      pcre = `^[0-9]{4}-[0-9]{2}-[0-9]{2} ([01][0-9]|2[0-3]):[0-5][0-9]:[0-5][0-9](\.[0-9]{1,7})?$` ).
      RAISE EXCEPTION NEW zcx_exed_ptax( detail = 'BACEN quotation timestamp is invalid' ).
    ENDIF.
    IF ls_bulletin-timestamp+0(10) <> lv_expected_date
       OR ls_bulletin-timestamp+10(1) <> ' '.
      RAISE EXCEPTION NEW zcx_exed_ptax( detail = 'BACEN returned a different quotation date' ).
    ENDIF.
    rs_quote-found = abap_true.
    rs_quote-buy_rate = ls_bulletin-buy_rate.
    rs_quote-bulletin_timestamp = ls_bulletin-timestamp.
  ENDMETHOD.

  METHOD if_xco_json_tree_visitor~on_start.
    CLEAR: mv_depth, mv_member, mv_root_object, mv_value_count, mv_value_array,
           mv_in_value, mv_json_error, mt_bulletins.
  ENDMETHOD.

  METHOD if_xco_json_tree_visitor~on_end.
  ENDMETHOD.

  METHOD if_xco_json_tree_visitor~visit_member.
    mv_member = iv_name.
    IF mv_depth = 1 AND iv_name = 'value'.
      mv_value_count += 1.
    ENDIF.
  ENDMETHOD.

  METHOD if_xco_json_tree_visitor~enter_object.
    IF mv_depth = 0.
      mv_root_object = abap_true.
    ELSEIF mv_depth = 2 AND mv_in_value = abap_true.
      APPEND INITIAL LINE TO mt_bulletins.
    ELSE.
      check_json_value( 'O' ).
    ENDIF.
    mv_depth += 1.
    CLEAR mv_member.
  ENDMETHOD.

  METHOD if_xco_json_tree_visitor~leave_object.
    IF mv_depth = 3 AND mv_in_value = abap_true AND mt_bulletins IS NOT INITIAL.
      DATA(ls_row) = mt_bulletins[ lines( mt_bulletins ) ].
      IF ls_row-buy_seen = abap_false OR ls_row-timestamp_seen = abap_false
         OR ls_row-type_seen = abap_false.
        mv_json_error = 'Closing bulletin is missing mandatory fields'.
      ENDIF.
    ENDIF.
    mv_depth -= 1.
    CLEAR mv_member.
  ENDMETHOD.

  METHOD if_xco_json_tree_visitor~enter_array.
    IF mv_depth = 1 AND mv_member = 'value'.
      mv_value_array = abap_true.
      mv_in_value = abap_true.
    ELSE.
      check_json_value( 'A' ).
    ENDIF.
    mv_depth += 1.
    CLEAR mv_member.
  ENDMETHOD.

  METHOD if_xco_json_tree_visitor~leave_array.
    IF mv_depth = 2 AND mv_in_value = abap_true.
      mv_in_value = abap_false.
    ENDIF.
    mv_depth -= 1.
    CLEAR mv_member.
  ENDMETHOD.

  METHOD check_json_value.
    IF mv_depth = 1 AND mv_member = 'value'.
      mv_json_error = 'Root value must be an array'.
    ELSEIF mv_depth = 2 AND mv_in_value = abap_true.
      mv_json_error = 'Every value entry must be an object'.
    ELSEIF mv_depth = 3 AND mv_in_value = abap_true AND mt_bulletins IS NOT INITIAL.
      ASSIGN mt_bulletins[ lines( mt_bulletins ) ] TO FIELD-SYMBOL(<ls_row>).
      CASE mv_member.
        WHEN 'cotacaoCompra'.
          IF iv_kind <> 'N' OR <ls_row>-buy_seen = abap_true.
            mv_json_error = 'cotacaoCompra must be one JSON number'.
          ENDIF.
          <ls_row>-buy_seen = abap_true.
        WHEN 'dataHoraCotacao'.
          IF iv_kind <> 'S' OR <ls_row>-timestamp_seen = abap_true.
            mv_json_error = 'dataHoraCotacao must be one JSON string'.
          ENDIF.
          <ls_row>-timestamp_seen = abap_true.
        WHEN 'tipoBoletim'.
          IF iv_kind <> 'S' OR <ls_row>-type_seen = abap_true.
            mv_json_error = 'tipoBoletim must be one JSON string'.
          ENDIF.
          <ls_row>-type_seen = abap_true.
      ENDCASE.
    ENDIF.
  ENDMETHOD.

  METHOD if_xco_json_tree_visitor~visit_number.
    check_json_value( 'N' ).
    IF mv_depth = 3 AND mv_in_value = abap_true AND mv_member = 'cotacaoCompra'.
      ASSIGN mt_bulletins[ lines( mt_bulletins ) ] TO FIELD-SYMBOL(<ls_row>).
      <ls_row>-buy_rate = CONV decfloat34( iv_value ).
    ENDIF.
  ENDMETHOD.

  METHOD if_xco_json_tree_visitor~visit_string.
    check_json_value( 'S' ).
    IF mv_depth = 3 AND mv_in_value = abap_true AND mt_bulletins IS NOT INITIAL.
      ASSIGN mt_bulletins[ lines( mt_bulletins ) ] TO FIELD-SYMBOL(<ls_row>).
      CASE mv_member.
        WHEN 'dataHoraCotacao'.
          <ls_row>-timestamp = iv_value.
        WHEN 'tipoBoletim'.
          <ls_row>-bulletin_type = iv_value.
      ENDCASE.
    ENDIF.
  ENDMETHOD.

  METHOD if_xco_json_tree_visitor~visit_boolean.
    check_json_value( 'B' ).
  ENDMETHOD.

  METHOD if_xco_json_tree_visitor~visit_null.
    check_json_value( '0' ).
  ENDMETHOD.
ENDCLASS.
