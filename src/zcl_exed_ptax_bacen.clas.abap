CLASS zcl_exed_ptax_bacen DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES zif_exed_ptax_source.
    INTERFACES if_xco_json_tree_visitor.
    METHODS constructor IMPORTING communication_system TYPE string OPTIONAL.
  PRIVATE SECTION.
    TYPES:
      BEGIN OF closing_bulletin,
        buy_rate TYPE decfloat34,
        timestamp TYPE string,
        bulletin_type TYPE string,
        buy_seen TYPE abap_bool,
        timestamp_seen TYPE abap_bool,
        type_seen TYPE abap_bool,
      END OF closing_bulletin,
      closing_bulletins TYPE STANDARD TABLE OF closing_bulletin WITH EMPTY KEY.
    CONSTANTS max_attempts TYPE i VALUE 2.
    CONSTANTS timeout_seconds TYPE i VALUE 20.
    DATA communication_system TYPE string.
    DATA depth TYPE i.
    DATA member_name TYPE string.
    DATA root_is_object TYPE abap_bool.
    DATA value_count TYPE i.
    DATA value_is_array TYPE abap_bool.
    DATA inside_value_array TYPE abap_bool.
    DATA contract_error TYPE string.
    DATA bulletins TYPE closing_bulletins.
    METHODS build_query
      IMPORTING currency TYPE zif_exed_ptax_types=>bacen_currency_code requested_date TYPE d
      RETURNING VALUE(query) TYPE string RAISING zcx_exed_ptax.
    METHODS parse_response
      IMPORTING json_text TYPE string
                currency TYPE zif_exed_ptax_types=>bacen_currency_code requested_date TYPE d
      RETURNING VALUE(quote) TYPE zif_exed_ptax_types=>ptax_quote
      RAISING zcx_exed_ptax.
    METHODS check_json_value IMPORTING json_kind TYPE c.
    METHODS close_client
      IMPORTING client TYPE REF TO if_web_http_client
      RETURNING VALUE(close_error) TYPE string.
ENDCLASS.

CLASS zcl_exed_ptax_bacen IMPLEMENTATION.
  METHOD constructor.
    me->communication_system = communication_system.
  ENDMETHOD.

  METHOD build_query.
    IF currency <> 'USD' AND currency <> 'EUR' AND currency <> 'GBP'
       AND currency <> 'CHF' AND currency <> 'AUD'.
      RAISE EXCEPTION NEW zcx_exed_ptax( detail = |Unsupported BACEN currency { currency }| ).
    ENDIF.
    TRY.
        cl_abap_datfm=>conv_date_ext_to_int(
          EXPORTING im_datext = |{ requested_date+0(4) }-{ requested_date+4(2) }-{ requested_date+6(2) }|
                    im_datfmdes = '6'
          IMPORTING ex_datint = DATA(checked_date) ).
      CATCH cx_abap_datfm_no_date cx_abap_datfm_invalid_date
            cx_abap_datfm_format_unknown cx_abap_datfm_ambiguous INTO DATA(date_error).
        RAISE EXCEPTION NEW zcx_exed_ptax( detail = 'Invalid BACEN quotation date' previous = date_error ).
    ENDTRY.
    IF checked_date IS INITIAL.
      RAISE EXCEPTION NEW zcx_exed_ptax( detail = 'BACEN quotation date is required' ).
    ENDIF.
    " Esta consulta fixa recebe somente moeda permitida e data numérica validada.
    " Dois registros bastam para detectar boletins de fechamento duplicados.
    query = |@moeda='{ currency }'&@dataCotacao='{ requested_date+4(2) }-{ requested_date+6(2) }-{ requested_date+0(4) }'|
      && |&$filter=tipoBoletim%20eq%20'Fechamento%20PTAX'&$format=json&$top=2|
      && |&$select=cotacaoCompra,cotacaoVenda,dataHoraCotacao,tipoBoletim|.
  ENDMETHOD.

  METHOD zif_exed_ptax_source~get_quote.
    DATA(query) = build_query( currency = currency requested_date = requested_date ).
    DATA client TYPE REF TO if_web_http_client.
    DATA close_error TYPE string.
    DO max_attempts TIMES.
      DATA(attempt) = sy-index.
      CLEAR client.
      TRY.
          DATA destination TYPE REF TO if_http_destination.
          IF communication_system IS INITIAL.
            destination = cl_http_destination_provider=>create_by_comm_arrangement(
              comm_scenario = 'ZEXED_PTAX_COMM' service_id = 'ZEXED_PTAX_REST' ).
          ELSE.
            destination = cl_http_destination_provider=>create_by_comm_arrangement(
              comm_scenario = 'ZEXED_PTAX_COMM' service_id = 'ZEXED_PTAX_REST'
              comm_system_id = CONV #( communication_system ) ).
          ENDIF.
          client = cl_web_http_client_manager=>create_by_http_destination( destination ).
          client->enable_path_prefix( ).
          client->set_redirect_policy( abap_false ).
          DATA(request) = client->get_http_request( ).
          request->set_uri_path( '/CotacaoMoedaDia(moeda=@moeda,dataCotacao=@dataCotacao)' ).
          request->set_query( query ).
          request->set_header_field( i_name = 'Accept' i_value = 'application/json' ).
          DATA(response) = client->execute(
            i_method = if_web_http_client=>get i_timeout = timeout_seconds ).
          DATA(response_status) = response->get_status( ).
          DATA(retry_after) = response->get_header_field( 'Retry-After' ).
          IF response_status-code <> 200.
            close_error = close_client( client ).
            CLEAR client.
            " Respeitar Retry-After do servidor e não usar WAIT, que faz commit implícito.
            " Respostas 429/503 ou Retry-After exigem reprocessamento posterior do job.
            IF attempt < max_attempts AND retry_after IS INITIAL
               AND close_error IS INITIAL
               AND ( response_status-code = 502 OR response_status-code = 504 ).
              CONTINUE.
            ENDIF.
            RAISE EXCEPTION NEW zcx_exed_ptax(
              detail = |BACEN HTTP { response_status-code } for { currency }/{ requested_date DATE = ISO }; |
                && |attempt { attempt }; Retry-After={ retry_after }; close={ close_error }| ).
          ENDIF.
          DATA(response_body) = response->get_text( ).
          close_error = close_client( client ).
          CLEAR client.
          IF close_error IS NOT INITIAL.
            RAISE EXCEPTION NEW zcx_exed_ptax( detail = conv #( close_error ) ).
          ENDIF.
          quote = parse_response( json_text = response_body currency = currency requested_date = requested_date ).
          RETURN.
        CATCH cx_web_http_client_error INTO DATA(transport_error).
          close_error = close_client( client ).
          CLEAR client.
          IF attempt < max_attempts AND close_error IS INITIAL.
            CONTINUE.
          ENDIF.
          RAISE EXCEPTION NEW zcx_exed_ptax(
            detail = |BACEN transport failure for { currency }/{ requested_date DATE = ISO }; |
              && |attempt { attempt }; close={ close_error }|
            previous = transport_error ).
        CATCH cx_http_dest_provider_error cx_web_message_error INTO DATA(http_error).
          close_error = close_client( client ).
          CLEAR client.
          RAISE EXCEPTION NEW zcx_exed_ptax(
            detail = |BACEN communication configuration/message failure; close={ close_error }|
            previous = http_error ).
        CATCH zcx_exed_ptax INTO DATA(ptax_error).
          close_error = close_client( client ).
          IF close_error IS NOT INITIAL.
            RAISE EXCEPTION NEW zcx_exed_ptax(
              detail = |{ ptax_error->detail }; { close_error }| previous = ptax_error ).
          ENDIF.
          RAISE EXCEPTION ptax_error.
        CATCH cx_root INTO DATA(unexpected_error).
          close_error = close_client( client ).
          RAISE EXCEPTION NEW zcx_exed_ptax(
            detail = |Unexpected BACEN client failure; close={ close_error }|
            previous = unexpected_error ).
      ENDTRY.
    ENDDO.
    RAISE EXCEPTION NEW zcx_exed_ptax( detail = 'BACEN retry limit reached' ).
  ENDMETHOD.

  METHOD close_client.
    IF client IS NOT BOUND.
      RETURN.
    ENDIF.
    TRY.
        client->close( ).
      CATCH cx_web_http_client_error INTO DATA(close_failure).
        close_error = |HTTP client close failed: { close_failure->get_text( ) }|.
    ENDTRY.
  ENDMETHOD.

  METHOD parse_response.
    " Limpar o estado mesmo se o parser rejeitar a entrada antes de on_start.
    me->if_xco_json_tree_visitor~on_start( ).
    quote = VALUE #( currency = currency quotation_date = requested_date found = abap_false ).
    IF json_text IS INITIAL OR strlen( json_text ) > 32768.
      RAISE EXCEPTION NEW zcx_exed_ptax( detail = 'BACEN JSON body is empty or exceeds 32768' ).
    ENDIF.
    TRY.
        DATA(json_document) = xco_cp_json=>data->from_string( json_text ).
        json_document->traverse( me ).
      CATCH cx_root INTO DATA(json_error).
        RAISE EXCEPTION NEW zcx_exed_ptax( detail = 'Invalid BACEN JSON' previous = json_error ).
    ENDTRY.
    IF root_is_object = abap_false OR value_count <> 1 OR value_is_array = abap_false
       OR depth <> 0 OR contract_error IS NOT INITIAL.
      RAISE EXCEPTION NEW zcx_exed_ptax( detail = |Invalid BACEN JSON contract: { contract_error }| ).
    ENDIF.
    IF bulletins IS INITIAL.
      RETURN.
    ENDIF.
    IF lines( bulletins ) <> 1.
      RAISE EXCEPTION NEW zcx_exed_ptax( detail = 'multiple closing bulletins for one currency/date' ).
    ENDIF.
    DATA(bulletin) = bulletins[ 1 ].
    DATA(expected_date) = |{ requested_date+0(4) }-{ requested_date+4(2) }-{ requested_date+6(2) }|.
    IF bulletin-buy_rate <= 0 OR bulletin-bulletin_type <> 'Fechamento PTAX'.
      RAISE EXCEPTION NEW zcx_exed_ptax( detail = 'bulletin or positive purchase rate is invalid' ).
    ENDIF.
    " PCRE no ABAP ignora espaços literais; \x20 exige o separador data/hora.
    IF NOT matches( val = bulletin-timestamp
      pcre = `^[0-9]{4}-[0-9]{2}-[0-9]{2}\x20([01][0-9]|2[0-3]):[0-5][0-9]:[0-5][0-9](\.[0-9]{1,7})?$` ).
      RAISE EXCEPTION NEW zcx_exed_ptax( detail = 'BACEN quotation timestamp is invalid' ).
    ENDIF.
    " O separador já foi validado pela regex; comparar somente a data econômica.
    IF bulletin-timestamp+0(10) <> expected_date.
      RAISE EXCEPTION NEW zcx_exed_ptax( detail = 'BACEN returned a different quotation date' ).
    ENDIF.
    quote-found = abap_true.
    quote-buy_rate = bulletin-buy_rate.
    quote-bulletin_timestamp = bulletin-timestamp.
  ENDMETHOD.

  METHOD if_xco_json_tree_visitor~on_start.
    CLEAR: depth, member_name, root_is_object, value_count, value_is_array,
           inside_value_array, contract_error, bulletins.
  ENDMETHOD.

  METHOD if_xco_json_tree_visitor~on_end.
  ENDMETHOD.

  METHOD if_xco_json_tree_visitor~visit_member.
    member_name = iv_name.
    IF depth = 1 AND iv_name = 'value'.
      value_count += 1.
    ENDIF.
  ENDMETHOD.

  METHOD if_xco_json_tree_visitor~enter_object.
    IF depth = 0.
      root_is_object = abap_true.
    ELSEIF depth = 2 AND inside_value_array = abap_true.
      APPEND INITIAL LINE TO bulletins.
    ELSE.
      check_json_value( 'O' ).
    ENDIF.
    depth += 1.
    CLEAR member_name.
  ENDMETHOD.

  METHOD if_xco_json_tree_visitor~leave_object.
    IF depth = 3 AND inside_value_array = abap_true AND bulletins IS NOT INITIAL.
      DATA(bulletin_row) = bulletins[ lines( bulletins ) ].
      IF bulletin_row-buy_seen = abap_false OR bulletin_row-timestamp_seen = abap_false
         OR bulletin_row-type_seen = abap_false.
        contract_error = 'Closing bulletin is missing mandatory fields'.
      ENDIF.
    ENDIF.
    depth -= 1.
    CLEAR member_name.
  ENDMETHOD.

  METHOD if_xco_json_tree_visitor~enter_array.
    IF depth = 1 AND member_name = 'value'.
      value_is_array = abap_true.
      inside_value_array = abap_true.
    ELSE.
      check_json_value( 'A' ).
    ENDIF.
    depth += 1.
    CLEAR member_name.
  ENDMETHOD.

  METHOD if_xco_json_tree_visitor~leave_array.
    IF depth = 2 AND inside_value_array = abap_true.
      inside_value_array = abap_false.
    ENDIF.
    depth -= 1.
    CLEAR member_name.
  ENDMETHOD.

  METHOD check_json_value.
    IF depth = 1 AND member_name = 'value'.
      contract_error = 'Root value must be an array'.
    ELSEIF depth = 2 AND inside_value_array = abap_true.
      contract_error = 'Every value entry must be an object'.
    ELSEIF depth = 3 AND inside_value_array = abap_true AND bulletins IS NOT INITIAL.
      ASSIGN bulletins[ lines( bulletins ) ] TO FIELD-SYMBOL(<bulletin_row>).
      CASE member_name.
        WHEN 'cotacaoCompra'.
          IF json_kind <> 'N' OR <bulletin_row>-buy_seen = abap_true.
            contract_error = 'cotacaoCompra must be one JSON number'.
          ENDIF.
          <bulletin_row>-buy_seen = abap_true.
        WHEN 'dataHoraCotacao'.
          IF json_kind <> 'S' OR <bulletin_row>-timestamp_seen = abap_true.
            contract_error = 'dataHoraCotacao must be one JSON string'.
          ENDIF.
          <bulletin_row>-timestamp_seen = abap_true.
        WHEN 'tipoBoletim'.
          IF json_kind <> 'S' OR <bulletin_row>-type_seen = abap_true.
            contract_error = 'tipoBoletim must be one JSON string'.
          ENDIF.
          <bulletin_row>-type_seen = abap_true.
      ENDCASE.
    ENDIF.
  ENDMETHOD.

  METHOD if_xco_json_tree_visitor~visit_number.
    check_json_value( 'N' ).
    IF depth = 3 AND inside_value_array = abap_true AND member_name = 'cotacaoCompra'.
      ASSIGN bulletins[ lines( bulletins ) ] TO FIELD-SYMBOL(<bulletin_row>).
      <bulletin_row>-buy_rate = CONV decfloat34( iv_value ).
    ENDIF.
  ENDMETHOD.

  METHOD if_xco_json_tree_visitor~visit_string.
    check_json_value( 'S' ).
    IF depth = 3 AND inside_value_array = abap_true AND bulletins IS NOT INITIAL.
      ASSIGN bulletins[ lines( bulletins ) ] TO FIELD-SYMBOL(<bulletin_row>).
      CASE member_name.
        WHEN 'dataHoraCotacao'.
          <bulletin_row>-timestamp = iv_value.
        WHEN 'tipoBoletim'.
          <bulletin_row>-bulletin_type = iv_value.
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
