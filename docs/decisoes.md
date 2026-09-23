# Base e decisões de implementação

O responsável aprovou a especificação v0.5, o plano v1.0 e a entrega de fontes ao GitHub com dispensa explícita do Harness formal SDD. Foram mantidos revisão, verificações locais e registro das pendências SAP. Não é declarada certificação formal SDD.

Referências de conteúdo aprovadas nesta conversa:

| Artefato | SHA-256 |
|---|---|
| Especificação v0.5 | `4f6212ee458f83cf35afea98df5e759a5a4f1da86a4512beb4521ae777d31b40` |
| Plano v1.0 | `382cdb8cedfa6dab1f946ff6707ed569d572389f83ace6549e9c9491ffa28cec` |

Posteriormente foi aprovado o ajuste **“Aprovo a gravação por par”**: um commit por par, preservar sucessos, registrar o par com falha, continuar os demais e sinalizar falha do job ao final. Essa decisão substitui a proposta condicional de atomicidade do lote.

## Motivo do ajuste transacional

A leitura estrutural da implementação standard que sustenta a BOI mostrou numeração tardia processando somente a primeira instância nova do mapeamento. Não foi presumido suporte a múltiplos CREATEs no mesmo commit. O adapter entrega cada nova instância em uma LUW independente, captura mensagens também da fase de gravação e relê o valor persistido. A implementação dessa classe standard foi usada apenas como evidência de descoberta: seus fontes e identidades internas não são dependências do código entregue.

A gravação em DEV ainda precisa provar o comportamento completo de draft, locks, autorização, mensagens e commit. Uma leitura depois do commit confirma o estado corrente; não é um mecanismo de reversão. Em resultado incerto, o log pede reconciliação antes de reprocessar; não há retentativa cega de CREATE.

## Precisão e orientação

O campo de compra BACEN já representa BRL por unidade da moeda consultada. Para D, normalizar pela razão unidades-origem/unidades-destino. Para I, usar unidades-destino/unidades-origem e manter o indicador indireto. O campo released do BOI determina a precisão usada na comparação.

O comportamento de determinação observado resolve os fatores de I pelo par inverso e troca a orientação das unidades. O adapter reproduz essa resolução pela CDS released e confronta os fatores/valor/indicador retornados pela ação Determine antes da ativação. Fatores ausentes, não positivos, tipo alternativo ou divergência são erros explícitos.

## Ausência e falhas técnicas

Somente uma coleção `value:[]` dentro do contrato JSON válido é ausência de boletim. Campos ausentes/nulos, tipo incorreto, valor não positivo, boletins duplicados, data divergente, HTTP inválido e resposta malformada são erros.

Consultas usam a data selecionada e nunca recuam para outra. O cliente limita tempo/tentativas, fecha conexões e não usa WAIT com commit implícito. `429`, `503` ou `Retry-After` são registrados para reprocessamento posterior; não há retentativa imediata contrariando a espera indicada pelo servidor.

## Fontes de referência

- [BOI de taxas de câmbio](https://api.sap.com/bointerface/I_CURRENCYEXCHANGERATETP_2).
- [BACEN — conjunto PTAX](https://dadosabertos.bcb.gov.br/dataset/taxas-de-cambio-todos-os-boletins-diarios) e [documentação da API](https://www.bcb.gov.br/conteudo/dadosabertos/BCBDepin/gnastportal-dados-abertostaxas-de-cambio---todos-os-boletins-diarios.pdf).
- [SAP — lógica de Application Jobs](https://help.sap.com/docs/SAP_S4HANA_CLOUD/6aa39f1ac05441e5a23f484f31e477e7/99dcde1a72ed4e7fb0959ead46a7fbf5.html?locale=en-US).

O catálogo externo, as leituras de API State e os testes efetivamente executados são fontes distintas. O estado de execução está registrado em `validacao.md`.
