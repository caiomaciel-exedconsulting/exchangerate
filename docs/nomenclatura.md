# Correção de nomenclatura

O responsável informou ter corrigido a sintaxe, ativado os objetos no ADT e publicado a exportação. A refatoração usa como base o commit [2c1413aa4a5fd81257668b3fd8c912b3385b0d56](https://github.com/caiomaciel-exedconsulting/exchangerate/commit/2c1413aa4a5fd81257668b3fd8c912b3385b0d56).

Foram substituídos os prefixos de tipo, direção e escopo em identificadores próprios, incluindo `lv_`, `ls_`, `lt_`, `lo_`, `lx_`, `mv_`, `mt_`, `mo_`, `iv_`, `io_`, `is_`, `it_`, `rv_`, `rs_`, `rt_`, `ty_`, `tt_` e prefixos de classes locais de teste. Exemplos: `configured_pairs`, `current_rate`, `quotation_date`, `source`, `calendar_tests` e `rate_items`. Declarações, implementações, chamadas e testes foram ajustados juntos.

Foram preservados:

- Nomes e assinaturas definidos pela SAP, como `iv_name`/`iv_value` na interface XCO, parâmetros da interface de calendário e argumentos nomeados de APIs standard.
- Nomes globais `ZCL_*`, `ZIF_*` e `ZCX_*`, que identificam os objetos de repositório.
- Parâmetros públicos `P_REFERENCE`, `P_QUOTATION`, `P_CALENDAR`, `P_TIMEZONE`, `P_SIMULATE` e `P_COMSYS`, por compatibilidade com catálogo, template e agendamentos.
- Correções do ADT na exceção T100/MSGV1, conversões e chamadas EML, inclusive a chave da ação Activate. Literais, regras, operadores e ordem das instruções permanecem como na base recebida.
- Todos os metadados XML/JSON exportados pelo usuário, incluindo pacote e objeto SUSH.

Nos construtores, os atributos passaram a ser qualificados com `me->` quando compartilham o nome do parâmetro, para manter a atribuição correta.

## Verificações desta refatoração

- Parser ABAP Cloud e regra `no_prefixes`: 0 ocorrências, 31 arquivos analisados.
- Checagem estática local com declarações de dependências SAP: 0 ocorrências. Essa checagem não equivale ao compilador SAP.
- Comparação do patch: somente identificadores ABAP foram renomeados, com qualificação dos atributos nos construtores; metadados e exceção gerada pelo ADT não foram modificados.
- `git diff --check`: sem erros.

A regra `no_prefixes` foi incorporada ao `abaplint.json`, incluindo os tipos anteriormente prefixados por `ty_` e `tt_`, para detectar reincidência. A ativação relatada pelo responsável refere-se à base anterior à refatoração. Não foi executada nova ativação, ATC ou ABAP Unit no tenant durante esta alteração; após o pull, reativar os objetos modificados e executar os testes existentes.
