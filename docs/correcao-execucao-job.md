# Correção do cancelamento na execução do job

## Evidência e diagnóstico

Em 23/09/2026, o responsável enviou o cancelamento `CX_APJ_RT_CONTENT` em `ZCL_EXED_PTAX_JOB`, include `CM002`, linha 92 do método. No fonte consultado, essa linha relança uma falha anterior capturada em `CATCH cx_root`; ela não identifica a causa original.

O responsável também informou: `PTAX M/compra: referencia - - ; calendario BR; fuso BRAZIL; simulacao .`. Essa linha revela referência sem uma data válida e simulação desmarcada. O formato é compatível com um campo D preenchido com espaços. Os valores internos do agendamento não foram inspecionados diretamente.

O código só reconhecia `IS INITIAL`, que para D significa `00000000`. Oito espaços não satisfazem essa condição: a referência não recebe a data atual e uma cotação em espaços pode ser interpretada como data explicitamente informada. A SAP documenta a diferença entre datas iniciais e datas resultantes de campos de caracteres vazios em [conversão de string para data](https://help.sap.com/docs/abap-cloud/abap-keyword/source-field-type-string?locale=en-US&state=PRODUCTION&version=latest).

Um segundo defeito prejudicava o diagnóstico: `ZCX_EXED_PTAX` colocava o conteúdo de `DETAIL` no campo T100 `ATTR1`, destinado ao nome de um atributo. Além disso, `MSGV1` limitava o detalhe a 50 caracteres, e `GET_TEXT` podia apresentar somente a mensagem genérica. A distinção entre o nome do atributo e seu valor é demonstrada em [SAP Learning — Defining Your Own Exception Classes](https://learning.sap.com/courses/deepening-your-abap-programming-knowledge/defining-your-own-exception-classes_cf6cb318-246a-46ca-bd9a-f3eef5cbbb67).

## Alterações

- Normalizar `P_REFERENCE` e `P_QUOTATION` preenchidos somente com espaços antes de decidir a data.
- Manter a cotação explícita com prioridade; na ausência dela, calcular o dia útil anterior à referência. Referência vazia usa o dia corrente no fuso configurado.
- Recusar a data usada quando inválida e registrar o nome do parâmetro.
- Registrar os modos `SIMULACAO` ou `MANUTENCAO` por extenso, além da seleção de cotação automática/explícita.
- Preservar o detalhe completo em STRING e devolvê-lo em `GET_TEXT`; manter `PREVIOUS`, interfaces T100 e a chave explícita, com fallback herdado quando não houver detalhe.

O diagnóstico preserva a cadeia de causas no Application Log. O framework ainda pode apresentar `CX_APJ_RT_CONTENT` no log de cancelamento; o detalhe deve ser consultado no log `ZEXED_PTAX` / `IMPORT` associado à execução.

## Preservação da baseline

A correção incorpora as sincronizações `163a64c` e `0863631`, preservando os exports IAM SIA1/SIA7, publicação, configuração de comunicação, rótulos dos parâmetros e ajustes do template feitos pelo responsável. Uma entrada `IF_OO_ADT_CLASSRUN` apareceu durante a consulta ao fonte ativo, mas não integra a sincronização mais recente; ela não foi acrescentada ao repositório nem executada neste diagnóstico.

## Validação e próxima execução

Foram acrescentados sete testes de resolução dos parâmetros e cinco de mensagem/encadeamento da exceção. Eles usam valores determinísticos e não executam HTTP, o job ou manutenção de taxas. Parser, regra de nomenclatura e checagem sintática local passaram; não equivalem a ATC/ABAP Unit executados no tenant.

1. Fazer pull e ativar as duas classes e seus testes. Executar ATC e a suíte ampliada de 40 testes.
2. No próximo agendamento de diagnóstico, marcar `P_SIMULATE = X`. O registro anterior mostrava simulação vazia, que habilita manutenção; a correção não altera a escolha do operador.
3. Para a consulta automática, deixar `P_REFERENCE` e `P_QUOTATION` vazios; manter `BR`, `BRAZIL` e o sistema de comunicação aplicável.
4. Conferir no log uma referência válida, `cotacao automatica pelo calendario` e `modo SIMULACAO`.
5. Se ocorrer outra falha, copiar a mensagem detalhada do Application Log. Calendário, comunicação e autorizações de negócio precisam ser avaliados conforme essa causa; o cancelamento genérico não comprova falha em nenhum deles.

Nenhuma taxa foi gravada ou job executado pelo assistente. A resolução integral da execução depende da revalidação no SAP.
