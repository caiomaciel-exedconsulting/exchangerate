CLASS exception_tests DEFINITION FINAL FOR TESTING DURATION SHORT RISK LEVEL HARMLESS.
  PRIVATE SECTION.
    METHODS short_detail FOR TESTING.
    METHODS long_detail FOR TESTING.
    METHODS previous_preserved FOR TESTING.
    METHODS explicit_textid_preserved FOR TESTING.
    METHODS empty_detail_uses_fallback FOR TESTING.
    METHODS assert_rendered_text IMPORTING expected_text TYPE string.
ENDCLASS.

CLASS exception_tests IMPLEMENTATION.
  METHOD assert_rendered_text.
    DATA(error) = NEW zcx_exed_ptax( detail = expected_text ).
    DATA root TYPE REF TO cx_root.
    DATA message TYPE REF TO if_message.
    root = error.
    message = error.

    cl_abap_unit_assert=>assert_equals( act = error->detail exp = expected_text ).
    cl_abap_unit_assert=>assert_equals( act = root->get_text( ) exp = expected_text ).
    cl_abap_unit_assert=>assert_equals( act = message->get_text( ) exp = expected_text ).
  ENDMETHOD.

  METHOD short_detail.
    assert_rendered_text( `Calendario de fabrica BR nao encontrado.` ).
  ENDMETHOD.

  METHOD long_detail.
    DATA(expected_text) = `Falha na consulta PTAX para USD em 22.09.2026: `
      && `a causa tecnica completa precisa permanecer no log, sem truncamento em cinquenta caracteres.`.
    assert_rendered_text( expected_text ).
  ENDMETHOD.

  METHOD previous_preserved.
    DATA(cause) = NEW zcx_exed_ptax( detail = `Causa original.` ).
    DATA(error) = NEW zcx_exed_ptax( detail = `Contexto da falha.` previous = cause ).

    cl_abap_unit_assert=>assert_equals( act = error->previous exp = cause ).
    cl_abap_unit_assert=>assert_equals( act = error->get_text( ) exp = `Contexto da falha.` ).
    cl_abap_unit_assert=>assert_equals( act = error->previous->get_text( ) exp = `Causa original.` ).
  ENDMETHOD.

  METHOD explicit_textid_preserved.
    DATA(text_key) = if_t100_message=>default_textid.
    text_key-attr1 = 'DETAIL'.
    DATA(error) = NEW zcx_exed_ptax( textid = text_key detail = `Detalhe independente da chave T100.` ).

    cl_abap_unit_assert=>assert_equals( act = error->if_t100_message~t100key exp = text_key ).
  ENDMETHOD.

  METHOD empty_detail_uses_fallback.
    DATA(error) = NEW zcx_exed_ptax( ).
    DATA root TYPE REF TO cx_root.
    DATA message TYPE REF TO if_message.
    root = error.
    message = error.

    " O texto padrao depende do idioma de logon; deve continuar disponivel.
    cl_abap_unit_assert=>assert_not_initial( root->get_text( ) ).
    cl_abap_unit_assert=>assert_equals( act = message->get_text( ) exp = root->get_text( ) ).
    cl_abap_unit_assert=>assert_equals(
      act = error->if_t100_message~t100key exp = if_t100_message=>default_textid ).
  ENDMETHOD.
ENDCLASS.
