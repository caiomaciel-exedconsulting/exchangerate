# Backlog após o aceite do desenvolvimento

Em 23/09/2026, o responsável declarou o desenvolvimento concluído e decidiu adiar o teste integrado de ausência parcial de boletim. O comportamento aprovado permanece o mesmo: ignorar somente os pares da moeda sem boletim, preservar suas taxas existentes e continuar as demais moedas sem buscar outra data.

## Teste integrado de ausência parcial

- **Estado:** backlog; execução integrada `NOT_RUN`.
- **Cobertura existente:** testes unitários de ausência de USD/AUD em `ZCL_EXED_PTAX_SERVICE`, com doubles; não comprovam persistência integrada no SAP.
- **Risco ainda sem evidência integrada:** continuidade de manutenção dos outros pares e preservação dos pares ignorados na mesma execução real.
- **Responsável e prazo:** a definir quando o item for retomado.
- **Condição de retomada:** DEV e fonte de resposta controlada que permita ausência funcional somente para uma moeda, mantendo o contrato HTTP/JSON, sem alterar o endpoint produtivo.

### Preparação e resultado esperado

1. Preparar os sete registros com tipo, data, indicação D/I e fatores conhecidos. Registrar seus valores antes da execução.
2. Fornecer resposta válida HTTP 200 com `value: []` apenas para USD. As outras quatro moedas retornam boletins válidos da mesma data.
3. Com os outros valores já iguais à fonte, esperar **5 iguais, 2 pares sem boletim / 1 moeda, 0 criações, 0 atualizações e 0 erros**. BRL/USD e USD/BRL existentes devem permanecer intactos.
4. Para demonstrar continuidade de gravação, preparar divergência controlada apenas em EUR/BRL e repetir. Esperar **1 atualização, 4 iguais, 2 pares sem boletim / 1 moeda e 0 erros**, confirmando o estado após a execução.
5. Conferir ausência de consulta a outra data e ausência de manutenção dos pares USD. Restaurar a configuração de teste e registrar os resultados.

Falha de rede, HTTP 4xx/5xx, JSON inválido ou ausência em todas as moedas não reproduzem este cenário. A infraestrutura de resposta controlada ainda não foi criada. Nenhuma execução desse roteiro é afirmada neste documento.
