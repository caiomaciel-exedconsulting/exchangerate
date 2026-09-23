# Validação da entrega de fontes

Esta entrega contém 15 objetos ABAP Cloud, com gravação independente por par conforme ajuste aprovado. As verificações abaixo qualificam os fontes para importação e validação no ADT; não representam execução do job no SAP.

## Verificações executadas

| Verificação | Resultado |
|---|---|
| abaplint 2.120.58, parser ABAP Cloud, configuração publicada | 0 issues; 29 arquivos de objetos analisados |
| abaplint local, incluindo check_syntax e declarações de dependências | 0 issues; não substitui o compilador SAP |
| APLO, SAJC e SAJT | Válidos nos schemas AFF v1 oficiais da SAP, com Ajv draft 2020 |
| XML de metadados, comunicação e abapGit | 13 arquivos analisados sem erro de XML |
| Inventário | 15 objetos; nomes e referências cruzadas conferidos |
| Parâmetros do job | Seis parâmetros coerentes entre classe, catálogo e template |
| Metadados ABAP | Linguagem Cloud, Unicode, categoria de exceção e indicadores de testes conferidos |
| Formato dos fontes | UTF-8 sem BOM, término de linha e diff conferidos |
| Escrita standard | Sem manutenção direta de tabelas standard, COMMIT WORK ou WAIT UP TO nos fontes |

O `abaplint.json` distribuído verifica parsing. A checagem adicional local usou declarações auxiliares de dependências standard e não valida a totalidade dos contratos EML, a save sequence, autorizações ou comportamento em execução. As dependências auxiliares e implementações standard consultadas não integram o repositório.

Leituras somente de consulta confirmaram API State C1 e contratos dos principais objetos released utilizados no DEV conectado, incluindo a BOI e as CDS de taxas/fatores. Disponibilidade e ativação no sistema de destino continuam sujeitas à validação no ADT.

## Testes ABAP Unit incluídos

| Classe | Métodos de teste escritos | Execução no SAP |
|---|---:|---|
| ZCL_EXED_PTAX_BACEN | 8 | Base anterior: 4 sucessos e 2 erros; correção e 2 testes novos aguardam execução |
| ZCL_EXED_PTAX_CALENDAR | 5 | 5 sucessos na execução enviada pelo responsável |
| ZCL_EXED_PTAX_RATE_STORE | 8 | 8 sucessos na execução enviada pelo responsável |
| ZCL_EXED_PTAX_SERVICE | 7 | 7 sucessos na execução enviada pelo responsável |
| Total | 28 | Base anterior: 24 sucessos em 26 testes; nova execução pendente |

Os testes acompanham os fontes em arquivos `.clas.testclasses.abap`. A existência e a análise estática desses arquivos não são resultados de ABAP Unit. Casos de integração com persistência, locks e save sequence exigem validação no tenant.

A revisão dos fontes também corrigiu a categoria da classe de exceção, a preservação do texto/cadeia de causas no log e a revalidação de taxas inicialmente classificadas como iguais antes de mantê-las sem gravação.

## Correção dos erros de data/hora BACEN

As imagens enviadas pelo responsável mostram dois erros: `MAP_PURCHASE_QUOTE` e `NO_BULLETIN_IS_NOT_ERROR`. Ambos passam pela mesma chamada, pois o segundo teste começa carregando uma cotação válida para verificar a limpeza do estado na resposta seguinte. O método ativo foi consultado no SAP; a linha 31 de `PARSE_RESPONSE`, indicada na pilha, corresponde à rejeição do formato de data/hora.

A expressão regular tinha um espaço literal entre data e hora. Nas funções ABAP com PCRE, o modo estendido ignora esse espaço no padrão. O separador foi substituído por `\x20`, que exige exatamente um espaço, sem ampliar os formatos aceitos. Referência: [SAP — sintaxe PCRE e modo estendido](https://help.sap.com/doc/abapdocu_816_index_htm/8.16/en-US/ABENREGEX_PCRE_SYNTAX.html).

Dois métodos de regressão foram acrescentados: aceitação de segundos sem fração ou com 1, 3 e 7 casas; rejeição de separador ausente, `T`, espaço duplicado, tabulação, hora/minuto/segundo inválidos e fração vazia ou excessiva. A verificação local com PCRE2 10.48 e modo estendido confirmou os 13 casos; o padrão anterior rejeitava os quatro exemplos válidos. Essa execução valida o padrão, não equivale a ABAP Unit nem à execução do leitor JSON no SAP.

Parser, `no_prefixes` e checagem estática local passaram sem ocorrências. A correção foi feita nos fontes; a classe e seus testes devem ser reativados e a suíte de 28 métodos reexecutada no ADT. Nenhuma gravação de taxas foi necessária para o diagnóstico.

## Verificações pendentes no SAP

1. Importar os objetos para `ZEXED_FI_TAXA_CAMBIO` / `ZCUSTOM_DEVELOPMENT`, executar syntax check e ativar todas as dependências no ADT.
2. Executar ATC e os 28 métodos de ABAP Unit da versão corrigida; resolver eventuais incompatibilidades com o release de destino.
3. Publicar/configurar o cenário de comunicação e testar HTTPS com o BACEN a partir do tenant, conforme [comunicacao.md](comunicacao.md).
4. Confirmar o calendário legado `BR`, seu mapeamento FHC, cobertura de datas, fatores de conversão e regras do fuso configurado. `BRAZIL` é o valor inicial do parâmetro; sua existência e correspondência ao fuso de Brasília precisam ser conferidas no tenant.
5. Executar simulação com boletins conhecidos e conferir data, sete pares, orientação D/I, precisão, fatores e Application Log. Validar ausência de uma moeda sem impedir as demais e sem recuar a data.
6. Em DEV, provar criação, igualdade, atualização e reexecução pela BOI. Validar autorizações, locks, concorrência, erro em um par com preservação dos demais, mensagem de falha do job e reconciliação após resultado de commit incerto.
7. Após aceite operacional, configurar execução diária às 07:00 de Brasília, com datas vazias e simulação desmarcada. Coordenar a desativação do RPA para evitar manutenção concorrente.

Na preparação inicial, não foram executados ativação SAP, ATC, ABAP Unit, gravação real de taxas, comunicação HTTPS do tenant ou agendamento produtivo. Posteriormente, o responsável informou a ativação e enviou os resultados de ABAP Unit registrados acima. A execução da correção e as demais verificações operacionais continuam pendentes. O template distribuído inicia em simulação.

## Governança

A correção de idioma solicitada após o primeiro pull alinha `MASTER_LANGUAGE` e `LANGU` para `P`, e `originalLanguage` para `pt`. Descrições dos objetos, rótulos do catálogo e comentários foram traduzidos; os identificadores técnicos, a versão de linguagem ABAP Cloud e a lógica executável foram preservados. O erro relatado no ADT indicava login `PT` versus idioma principal `EN`. A repetição do pull no ADT ainda precisa confirmar a importação da correção.

Os códigos foram conferidos na [tabela oficial SAP AFF de idiomas](https://github.com/SAP/abap-file-formats/blob/main/docs/languages.md) e na [documentação do idioma principal abapGit](https://docs.abapgit.org/user-guide/repo-settings/dot-abapgit.html). A correção passou novamente pela análise XML/JSON, schemas AFF e parser abaplint. A comparação com a versão anterior confirmou que os arquivos ABAP mudaram somente em comentários.

Especificação, plano, upload ao GitHub e ajuste de gravação por par foram aprovados pelo responsável. A dispensa do Harness formal SDD foi autorizada explicitamente para esta entrega de fontes, mantendo as verificações disponíveis e as pendências documentadas. Não há declaração de certificação formal SDD. Consulte [decisoes.md](decisoes.md).
