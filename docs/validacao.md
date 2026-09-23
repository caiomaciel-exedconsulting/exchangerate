# Validação da entrega de fontes

O núcleo contém 15 objetos ABAP Cloud, com gravação independente por par conforme ajuste aprovado, além dos exports IAM acrescentados pelo responsável. Este documento distingue verificações locais, confirmação do responsável e execuções do job demonstradas nos logs enviados.

**Encerramento em 23/09/2026:** o responsável declarou o desenvolvimento concluído e transferiu o teste integrado de ausência parcial de boletim para o [backlog](backlog.md). A revisão de código entregue é `ad1137dacf66c6421618abb8e726e3466da49b06`. As atualizações posteriores deste registro são documentais.

Depois da correção dos parâmetros, a simulação concluiu com cinco boletins para 22/09/2026 e sete criações previstas. A primeira manutenção falhou em Activate antes dos commits. Após a correção que preserva o PID na ativação, os logs compartilhados demonstraram as execuções abaixo. Consulte o diagnóstico histórico em [correcao-ativacao-boi.md](correcao-ativacao-boi.md).

## Resultados funcionais observados nos logs

Todos os resultados abaixo usam cotação de 22/09/2026, tipo M/compra, calendário BR e fuso BRAZIL.

| Cenário | Resultado informado pelo log | Evidência e limite |
|---|---|---|
| Simulação | 7 criações previstas; 0 erros | Cinco boletins consultados; modo SIMULACAO, sem manutenção |
| Primeira manutenção após a correção | 7 criações; 0 erros | Cada par informa leitura de confirmação após seu COMMIT |
| Reexecução da mesma data | 7 iguais; 0 criações/atualizações/erros | Taxas e fatores revalidados, sem alteração ou COMMIT |
| Correção de divergência dos dois pares USD | 2 atualizações; 5 iguais; 0 erros | BRL/USD I e USD/BRL D atualizados para 5,11550; confirmação após COMMIT |
| Reexecução após a atualização | 7 iguais; 0 criações/atualizações/erros | Demonstra idempotência após a atualização no cenário exercitado |

As evidências são as imagens dos logs enviadas pelo responsável nesta conversa em 23/09/2026. O assistente não executou as gravações nem releu diretamente os registros nesta etapa. Os logs demonstram criação, igualdade, atualização direta/indireta e reprocessamento; não demonstram ausência parcial, concorrência ou todos os limites de fatores/precisão.

## Verificações executadas

| Verificação | Resultado |
|---|---|
| abaplint 2.120.58, parser ABAP Cloud e nomenclatura, configuração publicada | 0 issues; 35 arquivos de objetos analisados na correção do job |
| abaplint local, incluindo check_syntax e declarações de dependências | 0 issues; não substitui o compilador SAP |
| APLO, SAJC e SAJT | Válidos nos schemas AFF v1 oficiais da SAP, com Ajv draft 2020 |
| XML de metadados, comunicação e abapGit | 13 arquivos analisados sem erro de XML |
| Inventário | 15 objetos; nomes e referências cruzadas conferidos |
| Parâmetros do job | Seis parâmetros coerentes entre classe, catálogo e template |
| Metadados ABAP | Linguagem Cloud, Unicode, categoria de exceção e indicadores de testes conferidos |
| Formato dos fontes | Alterações desta correção em UTF-8 sem BOM; exports anteriores do responsável preservados; diff conferido |
| Escrita standard | Sem manutenção direta de tabelas standard, COMMIT WORK ou WAIT UP TO nos fontes |

O `abaplint.json` distribuído verifica parsing. A checagem adicional local usou declarações auxiliares de dependências standard e não valida a totalidade dos contratos EML, a save sequence, autorizações ou comportamento em execução. As dependências auxiliares e implementações standard consultadas não integram o repositório.

Leituras somente de consulta confirmaram API State C1 e contratos dos principais objetos released utilizados no DEV conectado, incluindo a BOI e as CDS de taxas/fatores. Disponibilidade e ativação no sistema de destino continuam sujeitas à validação no ADT.

## Testes ABAP Unit incluídos

| Classe | Métodos de teste escritos | Execução no SAP |
|---|---:|---|
| ZCL_EXED_PTAX_BACEN | 8 | Suíte confirmada sem erros pelo responsável; sem novo detalhamento por método |
| ZCL_EXED_PTAX_CALENDAR | 5 | Suíte confirmada sem erros pelo responsável; sem novo detalhamento por método |
| ZCL_EXED_PTAX_RATE_STORE | 15 | Oito anteriores e sete regressões de ativação/diagnóstico; execução desta versão pendente |
| ZCL_EXED_PTAX_SERVICE | 7 | Suíte confirmada sem erros pelo responsável; sem novo detalhamento por método |
| ZCL_EXED_PTAX_JOB | 6 | Quantidade após sincronização do responsável em 329268b; fontes preservados |
| ZCX_EXED_PTAX | 5 | Novos testes de mensagem e encadeamento; execução no SAP pendente |
| Total | 46 nos fontes | Confirmação anterior de testes não comprova esta versão; reexecução pendente |

Os testes acompanham os fontes em arquivos `.clas.testclasses.abap`. A existência e a análise estática desses arquivos não são resultados de ABAP Unit. Casos de integração com persistência, locks e save sequence exigem validação no tenant.

A revisão dos fontes também corrigiu a categoria da classe de exceção, a preservação do texto/cadeia de causas no log e a revalidação de taxas inicialmente classificadas como iguais antes de mantê-las sem gravação.

## Correção dos erros de data/hora BACEN

A correção anterior do parser BACEN partiu do commit `fa1f431`, que inclui a alteração do calendário feita pelo responsável. Essa alteração foi preservada.

As imagens enviadas pelo responsável mostram dois erros: `MAP_PURCHASE_QUOTE` e `NO_BULLETIN_IS_NOT_ERROR`. Ambos passam pela mesma chamada, pois o segundo teste começa carregando uma cotação válida para verificar a limpeza do estado na resposta seguinte. O método ativo foi consultado no SAP; a linha 31 de `PARSE_RESPONSE`, indicada na pilha, corresponde à rejeição do formato de data/hora.

A expressão regular tinha um espaço literal entre data e hora. Nas funções ABAP com PCRE, o modo estendido ignora esse espaço no padrão. O separador foi substituído por `\x20`, que exige exatamente um espaço, sem ampliar os formatos aceitos. Referência: [SAP — sintaxe PCRE e modo estendido](https://help.sap.com/doc/abapdocu_816_index_htm/8.16/en-US/ABENREGEX_PCRE_SYNTAX.html).

Dois métodos de regressão foram acrescentados: aceitação de segundos sem fração ou com 1, 3 e 7 casas; rejeição de separador ausente, `T`, espaço duplicado, tabulação, hora/minuto/segundo inválidos e fração vazia ou excessiva. A verificação local com PCRE2 10.48 e modo estendido confirmou os 13 casos; o padrão anterior rejeitava os quatro exemplos válidos. Essa execução valida o padrão, não equivale a ABAP Unit nem à execução do leitor JSON no SAP.

Depois desse ajuste, o responsável enviou três erros em `MAP_PURCHASE_QUOTE`, `NO_BULLETIN_IS_NOT_ERROR` e `ACCEPT_TIMESTAMP_PRECISION`. A linha 36 de `PARSE_RESPONSE`, confirmada pela consulta ao fonte ativo, é a comparação posterior ao formato. O operando `bulletin-timestamp+10(1)` é `STRING`, mas o literal `' '` é `CHAR`: a conversão implícita remove o espaço do literal, fazendo um espaço válido parecer diferente de texto vazio. Referência: [SAP — comparação de dados de caracteres](https://help.sap.com/doc/abapdocu_752_index_htm/7.52/en-US/abenlogexp_character.htm).

A comparação redundante do separador foi removida; o padrão `\x20` continua exigindo exatamente um espaço. A comparação dos dez primeiros caracteres com a data solicitada permanece intacta. O teste de data divergente verifica a mensagem específica da exceção para datas anterior e posterior, evitando um falso sucesso causado por rejeição indevida do formato. Os casos positivos também conferem a data econômica retornada. Naquele ajuste a suíte permaneceu com 28 métodos; a correção posterior do job acrescentou 12.

Parser, `no_prefixes` e checagem estática local passaram sem ocorrências após a correção da comparação. As evidências PCRE2 acima pertencem à validação da expressão regular; não executam a semântica de comparação ABAP. Depois da entrega da correção no commit `50e7eee`, o responsável confirmou ATC e ABAP Unit sem erros. Nenhuma gravação de taxas foi necessária para o diagnóstico.

## Limites da evidência e operação posterior

- **Backlog aceito:** teste integrado de ausência parcial de boletim, ainda `NOT_RUN`. A cobertura unitária existente não substitui essa execução; detalhes em [backlog.md](backlog.md).
- **ABAP Unit/ATC:** o responsável confirmou anteriormente resultado sem erros. Há 46 métodos nos fontes atuais; não foi recebido relatório completo da reexecução dessa revisão. A conclusão aceita não transforma essa lacuna de evidência em um resultado de teste.
- **Cenários não demonstrados pelos logs recebidos:** feriados, virada de ano, limites de calendário, fatores diferentes de 1/1, precisão extrema, locks/concorrência, falha parcial de gravação e reconciliação de commit incerto. Permanecem limites da cobertura observada; não são declarados como executados.
- **Outros ambientes:** conferir comunicação e autorizações conforme [comunicacao.md](comunicacao.md) e [autorizacoes.md](autorizacoes.md). Objetos ativados e uma execução bem-sucedida não comprovam a configuração de outro ambiente.
- **Operação recorrente:** execução diária às 07:00 de Brasília continua sendo a configuração prevista. Não foi apresentada evidência do agendamento ou da desativação do RPA. No agendamento, conferir datas vazias, simulação desmarcada, usuário e fuso da tela de recorrência. O template distribuído inicia em simulação.

O desenvolvimento foi concluído por decisão explícita do responsável. Esse registro documenta o aceite e seus limites, sem criar aprovação, gate ou certificação formal do Harness.

## Governança

A correção de idioma solicitada após o primeiro pull alinha `MASTER_LANGUAGE` e `LANGU` para `P`, e `originalLanguage` para `pt`. Descrições dos objetos, rótulos do catálogo e comentários foram traduzidos; os identificadores técnicos, a versão de linguagem ABAP Cloud e a lógica executável foram preservados. O erro relatado no ADT indicava login `PT` versus idioma principal `EN`. Posteriormente, o responsável confirmou a ativação dos objetos e a execução dos testes.

Os códigos foram conferidos na [tabela oficial SAP AFF de idiomas](https://github.com/SAP/abap-file-formats/blob/main/docs/languages.md) e na [documentação do idioma principal abapGit](https://docs.abapgit.org/user-guide/repo-settings/dot-abapgit.html). A correção passou novamente pela análise XML/JSON, schemas AFF e parser abaplint. A comparação com a versão anterior confirmou que os arquivos ABAP mudaram somente em comentários.

Especificação, plano, upload ao GitHub e ajuste de gravação por par foram aprovados pelo responsável. A dispensa do Harness formal SDD foi autorizada explicitamente para esta entrega de fontes, mantendo as verificações disponíveis e as pendências documentadas. Não há declaração de certificação formal SDD. Consulte [decisoes.md](decisoes.md).
