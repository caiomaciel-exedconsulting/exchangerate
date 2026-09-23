# Correção da identidade do draft na ativação

## Evidência recebida

Em 23/09/2026, o responsável enviou duas execuções para a cotação de 22/09/2026:

- **Simulação concluída:** referência 23/09/2026, cinco boletins BACEN, sete criações previstas, fatores 1/1 e zero erros.
- **Manutenção com falha:** os sete pares chegaram à ação `Activate`; o log registrou descarte antes do COMMIT, criar=0, atualizar=0 e erros=7.

Esses resultados vêm das imagens do usuário. O assistente não executou o job nem conferiu diretamente as taxas persistidas. O segundo log, com `CX_APJ_RT_CONTENT`, reflete o cancelamento do job após os erros por par.

## Defeito e correção

A definição de comportamento subjacente à BOI `I_CurrencyExchangeRateTP_2`, consultada em modo somente leitura no DEV, declara **late numbering**. Um novo draft possui um identificador provisório `%pid`; a chave de negócio final pode continuar inicial durante a interação.

O código preservava a identidade retornada no MAPPED durante UPDATE, Determine, READ e Prepare, mas construía a entrada de Activate apenas com `%key`. Isso descartava o `%pid`. A correção usa `%pky`, que reúne `%pid` e `%key`, através de um método tipado com `TABLE FOR ACTION IMPORT ...~Activate`. A SAP documenta essa composição e o uso em ações draft em [ABAP Keyword Documentation — %pky](https://help.sap.com/docs/abap-cloud/abap-keyword/pky?locale=en-US&state=PRODUCTION&version=latest).

O mesmo mapeamento preserva chaves completas de taxas existentes. Não é usado `%tky` na entrada de Activate, pois o indicador de draft não integra essa entrada. O método exige exatamente um rascunho, mantendo o limite aprovado de um par por LUW. Nenhum commit adicional, privilégio ou atualização direta de tabela foi introduzido.

## Diagnóstico RAP

O verificador anterior detectava FAILED não vazio, mas exibia somente mensagens de REPORTED. Agora acrescenta a causa RAP pelo nome e código, PID e campos da chave de cada instância em FAILED. Assim, um retorno sem mensagem explicará, por exemplo, `NOT_FOUND (404)`, `UNAUTHORIZED (401)` ou `LOCKED (423)`.

O contrato RAP permite falhas sem mensagem associada em certos casos; a causa precisa ser lida em `%fail-cause`. Referências: [General RAP BO Implementation Contract](https://help.sap.com/docs/abap-cloud/abap-rap/general-rap-bo-implementation-contract) e [Using %fail](https://help.sap.com/docs/abap-cloud/abap-keyword/using-fail?locale=en-US&state=PRODUCTION&version=latest). Os nomes e códigos usados no log foram conferidos no contrato `IF_ABAP_BEHV` do tenant.

A perda de PID é um defeito demonstrado no fonte e compatível com a falha observada. A causa RAP original não foi registrada pela versão anterior; não se declara `NOT_FOUND` como resultado efetivamente observado nessa execução. A confirmação funcional depende do novo teste no SAP.

## Verificação e reexecução

Os novos ABAP Unit constroem somente estruturas de entrada/resposta: verificam preservação do PID, chave de edição, combinação dos dois, limite de um par e falha sem REPORTED. Eles não criam drafts, chamam HTTP ou executam EML.

1. Fazer pull, ativar `ZCL_EXED_PTAX_RATE_STORE` e seus testes e executar ATC/ABAP Unit da versão atual.
2. Em DEV, repetir o teste com `P_QUOTATION = 22.09.2026` e simulação desmarcada. Se as sete chaves continuarem ausentes, o resultado esperado é sete criações confirmadas e zero erros.
3. Repetir a mesma data. Sem alterações de cotação ou fatores, o esperado é sete taxas iguais e nenhuma manutenção adicional.
4. Se houver falha, usar o novo diagnóstico do Application Log para identificar a causa. A validação de criação, atualização e reexecução continua pendente até haver evidência dos resultados.

A baseline desta correção é `329268b`; as sincronizações e ajustes do usuário foram preservados.
