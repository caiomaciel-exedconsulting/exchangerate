# Importação de taxas de câmbio PTAX

Application Job ABAP Cloud para SAP S/4HANA Cloud Public Edition. Consulta o fechamento diário do BACEN e mantém taxas do tipo **M**, sempre pela **cotação de compra**, usando a BOI released `I_CurrencyExchangeRateTP_2`.

**Entrega de fontes para pull pelo ADT.** A simulação enviada pelo responsável concluiu com cinco boletins, sete criações previstas e zero erros. A execução em manutenção falhou em `Activate` nos sete pares, antes dos commits. Esta correção preserva a identidade provisória do draft na ativação e amplia o diagnóstico RAP; a gravação corrigida ainda precisa ser validada no SAP. Consulte [correção da ativação](docs/correcao-ativacao-boi.md), [correção anterior dos parâmetros](docs/correcao-execucao-job.md) e [validações e pendências](docs/validacao.md).

## Comportamento

| Origem | Destino | Moeda consultada no BACEN | Cotação SAP |
|---|---|---|---|
| BRL | USD | USD | I |
| USD | BRL | USD | D |
| BRL | EUR | EUR | I |
| EUR | BRL | EUR | D |
| GBP | BRL | GBP | D |
| CHF | BRL | CHF | D |
| AUD | BRL | AUD | D |

- Execução diária prevista às **07:00 de Brasília**, inclusive fins de semana.
- Data consultada: dia útil estritamente anterior pelo calendário de fábrica **BR**. A vigência SAP é a data da cotação, não a data de execução.
- Cinco consultas por data, reutilizadas nos sete pares. Não buscar outra data quando faltar boletim.
- USD ausente: ignorar somente BRL/USD e USD/BRL; demais pares continuam. A mesma regra vale para as outras moedas. Taxas existentes dos pares ignorados permanecem intactas.
- Chave ausente: criar. Valor normalizado igual: manter. Valor diferente: atualizar.
- Cotação indireta é expressa por `I`; não calcular o recíproco e marcar `I` simultaneamente. Os fatores SAP participam da normalização; não são presumidos como 1:1.
- **Uma transação por par.** Sucessos anteriores são preservados se outro par falhar. O erro fica no log, o processamento continua e o job termina com falha se houver erro de manutenção. Reprocessar a mesma data relê o estado SAP antes de decidir a ação.
- Erros HTTP/JSON ou de configuração não são tratados como ausência de boletim. A coleta e a inspeção acontecem antes da primeira gravação.

## Importação e configuração

1. Fazer pull pelo abapGit no ADT para o pacote `ZEXED_FI_TAXA_CAMBIO`, no componente `ZCUSTOM_DEVELOPMENT`. Confirmar o vínculo do pacote e a compatibilidade dos tipos de objeto no release.
2. Ativar tipos/interfaces e exceção, classes, objeto de log, serviço/cenário de comunicação, catálogo e template conforme suas dependências. Conferir todos os erros de ativação antes de executar.
3. Configurar o acesso BACEN conforme [comunicacao.md](docs/comunicacao.md): cenário `ZEXED_PTAX_COMM`, serviço `ZEXED_PTAX_REST`, HTTPS anônimo e host `olinda.bcb.gov.br`.
4. **Configurar as autorizações antes de acessar o job.** No ADT, criar/publicar um Business Catalog contendo a IAM App `ZEXED_PTAX_JOB_SAJC`. No Fiori, atribuir esse catálogo a uma Business Role e atribuir a role ao usuário. Conferir também o acesso ao app Application Jobs. Seguir [autorizacoes.md](docs/autorizacoes.md).
5. Confirmar o calendário legado `BR`, seu mapeamento FHC/cobertura, os fatores M e o identificador do fuso de Brasília. O valor inicial `BRAZIL` deve ser conferido no tenant.
6. Executar os testes ABAP Unit e ATC no ADT após importar alterações executáveis. Com as autorizações configuradas, executar primeiro o template `ZEXED_PTAX_DAILY` em simulação, conferir os sete resultados e abrir o Application Log.
7. Validar a manutenção e a reexecução em DEV. Só depois configurar a recorrência às 07:00, com simulação desmarcada e datas de referência/cotação vazias. Configurar o fuso também na tela de agendamento.

O pull não cria Communication System/Arrangement, Business Role ou sua atribuição ao usuário, nem agenda o job. O responsável incluiu no commit `163a64c` o Business Catalog IAM `ZEXED_PTAX` e sua atribuição `ZEXED_PTAX_0001`; conferir a configuração de cada ambiente no [guia de autorizações](docs/autorizacoes.md). O catálogo de job `ZEXED_PTAX_JOB` (SAJC) não substitui o Business Catalog IAM. A substituição operacional do RPA deve ocorrer depois do aceite, evitando dois escritores sobre as mesmas chaves.

O idioma principal do repositório e dos objetos é **português**: `P` nos metadados SAP XML e `pt` nos arquivos AFF. Usar login **PT** no ADT. A versão inicial estava em inglês; para o erro `Current login language 'PT' does not match main language 'EN'`, atualizar a referência remota da branch `main` e repetir o pull com a versão corrigida. O pull não converte o idioma original de objetos que já tenham sido criados em inglês; esse caso exige verificar o estado dos objetos antes de qualquer recriação.

Para reprocessar, informar `P_QUOTATION` com a data econômica desejada. Essa data é usada exatamente, sem fallback. Se vazia, o job calcula o dia útil anterior a `P_REFERENCE`; referência vazia usa a data corrente no fuso configurado.

## Objetos e implementação

O núcleo contém 15 objetos: quatro interfaces, seis classes (incluindo a exceção), APLO, SAJC, SAJT, SCO1 e SCO3. O responsável acrescentou os exports do Business Catalog IAM e da atribuição de app. Testes locais acompanham as classes aplicáveis em arquivos `.clas.testclasses.abap`.

`ZCL_EXED_PTAX_SERVICE` coordena os adapters de calendário, BACEN e persistência. `ZCL_EXED_PTAX_JOB` implementa `IF_APJ_RT_RUN` e registra boletins, pares, decisões, fatores, contadores e erros no log `ZEXED_PTAX`/`IMPORT`.

O adapter SAP lê `I_ExchangeRateRawData` e `I_ExchangeRateFactorsRawData` e escreve somente pela BOI. O fluxo draft/Determine/Prepare/Activate usa uma LUW por par. Não usa modo privilegiado, escrita direta em tabelas standard nem exclusão de taxas. Configuração de tipo alternativo de câmbio é recusada explicitamente para revisão; esse caso não é convertido silenciosamente para outro tipo.

As leituras de API State confirmaram os contratos principais no DEV conectado. Isso não substitui ativação, testes de autorização, locks, fatores e save sequence no ambiente de destino. [Contrato e decisões](docs/decisoes.md).

## Verificações locais

`npx @abaplint/cli@2.120.58` executa o parser ABAP Cloud e a regra `no_prefixes` com o `abaplint.json` incluído. A configuração publicada verifica parsing e nomenclatura; a verificação semântica completa depende dos objetos standard do release. Na preparação também foi executada uma checagem estática local com declarações de dependências, descrita no relatório, sem equivalência a syntax check/ATC do ADT.

Variáveis, atributos, parâmetros próprios, tipos e classes locais usam nomes sem notação húngara. Nomes herdados de APIs SAP e identificadores globais dos objetos são preservados. Os parâmetros públicos `P_*` permanecem como contrato do catálogo/template e de agendamentos. A refatoração partiu das correções ativadas e publicadas pelo responsável no commit `2c1413a`; detalhes em [nomenclatura.md](docs/nomenclatura.md).

Os schemas AFF v1 da SAP foram usados para validar APLO/SAJC/SAJT; os XML foram analisados e as referências cruzadas conferidas. Nenhuma chave, credencial ou cópia de implementação standard SAP faz parte desta entrega.
