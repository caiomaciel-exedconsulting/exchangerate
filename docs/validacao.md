# Validação da entrega de fontes

O núcleo contém 15 objetos ABAP Cloud, com gravação independente por par conforme ajuste aprovado, além dos exports IAM acrescentados pelo responsável. As verificações abaixo qualificam os fontes para importação e validação no ADT; não representam execução do job no SAP.

**Atualização em 23/09/2026:** depois da correção dos parâmetros, a imagem enviada pelo responsável confirmou simulação concluída, cinco boletins para 22/09/2026 e sete criações previstas sem erros. A manutenção falhou em Activate nos sete pares, com descarte antes dos commits. A correção atual preserva o PID na entrada de ativação e acrescenta diagnóstico de FAILED e sete testes. A baseline sincronizada pelo responsável continha 39 testes; agora são 46, ainda sem execução desta versão no SAP. Consulte [correção da ativação](correcao-ativacao-boi.md).

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

## Verificações pendentes no SAP

1. Importar/ativar `ZCL_EXED_PTAX_RATE_STORE` e seus testes; executar ATC e os 46 métodos de ABAP Unit. Os novos testes não executam EML, HTTP ou gravação de taxas.
2. Repetir em DEV a manutenção de 22/09/2026 e depois a reexecução da mesma data, conforme [correcao-ativacao-boi.md](correcao-ativacao-boi.md). Se as chaves continuarem ausentes, esperar sete criações confirmadas na primeira e sete iguais na segunda.
3. A simulação recebida comprova consulta HTTPS do job às cinco moedas nessa execução. Para outros ambientes, conferir cenário, arrangement e autorizações conforme [comunicacao.md](comunicacao.md) e [autorizacoes.md](autorizacoes.md).
4. A execução automática usou referência 23/09/2026 e encontrou 22/09/2026 pelo calendário BR. Ainda validar feriados, virada de ano, cobertura do calendário, fatores diferentes de 1/1 e limites de precisão relevantes.
5. Validar ausência de uma moeda sem impedir as demais e sem recuar a data. A simulação recebida encontrou boletins de todas as moedas e não cobre esse cenário.
6. Em DEV, provar criação, igualdade, atualização e reexecução pela BOI. Validar autorizações, locks, concorrência, erro em um par com preservação dos demais, mensagem de falha do job e reconciliação após resultado de commit incerto.
7. Após aceite operacional, configurar execução diária às 07:00 de Brasília, com datas vazias e simulação desmarcada. Coordenar a desativação do RPA para evitar manutenção concorrente.

O assistente não executou o job, EML ou gravação real de taxas. O responsável compartilhou as execuções de simulação e manutenção descritas acima e a confirmação anterior de ATC/ABAP Unit sem erros. Esses resultados não substituem a revalidação da nova correção de Activate. O template distribuído inicia em simulação; o operador deve conferir o valor na execução agendada.

## Governança

A correção de idioma solicitada após o primeiro pull alinha `MASTER_LANGUAGE` e `LANGU` para `P`, e `originalLanguage` para `pt`. Descrições dos objetos, rótulos do catálogo e comentários foram traduzidos; os identificadores técnicos, a versão de linguagem ABAP Cloud e a lógica executável foram preservados. O erro relatado no ADT indicava login `PT` versus idioma principal `EN`. Posteriormente, o responsável confirmou a ativação dos objetos e a execução dos testes.

Os códigos foram conferidos na [tabela oficial SAP AFF de idiomas](https://github.com/SAP/abap-file-formats/blob/main/docs/languages.md) e na [documentação do idioma principal abapGit](https://docs.abapgit.org/user-guide/repo-settings/dot-abapgit.html). A correção passou novamente pela análise XML/JSON, schemas AFF e parser abaplint. A comparação com a versão anterior confirmou que os arquivos ABAP mudaram somente em comentários.

Especificação, plano, upload ao GitHub e ajuste de gravação por par foram aprovados pelo responsável. A dispensa do Harness formal SDD foi autorizada explicitamente para esta entrega de fontes, mantendo as verificações disponíveis e as pendências documentadas. Não há declaração de certificação formal SDD. Consulte [decisoes.md](decisoes.md).
