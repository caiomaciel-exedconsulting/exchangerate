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
| ZCL_EXED_PTAX_BACEN | 6 | Pendente |
| ZCL_EXED_PTAX_CALENDAR | 5 | Pendente |
| ZCL_EXED_PTAX_RATE_STORE | 8 | Pendente |
| ZCL_EXED_PTAX_SERVICE | 7 | Pendente |
| Total | 26 | Não executados nesta entrega |

Os testes acompanham os fontes em arquivos `.clas.testclasses.abap`. A existência e a análise estática desses arquivos não são resultados de ABAP Unit. Casos de integração com persistência, locks e save sequence exigem validação no tenant.

A revisão dos fontes também corrigiu a categoria da classe de exceção, a preservação do texto/cadeia de causas no log e a revalidação de taxas inicialmente classificadas como iguais antes de mantê-las sem gravação.

## Verificações pendentes no SAP

1. Importar os objetos para `ZEXED_FI_TAXA_CAMBIO` / `ZCUSTOM_DEVELOPMENT`, executar syntax check e ativar todas as dependências no ADT.
2. Executar ATC e os 26 métodos de ABAP Unit; resolver eventuais incompatibilidades com o release de destino.
3. Publicar/configurar o cenário de comunicação e testar HTTPS com o BACEN a partir do tenant, conforme [comunicacao.md](comunicacao.md).
4. Confirmar o calendário legado `BR`, seu mapeamento FHC, cobertura de datas, fatores de conversão e regras do fuso configurado. `BRAZIL` é o valor inicial do parâmetro; sua existência e correspondência ao fuso de Brasília precisam ser conferidas no tenant.
5. Executar simulação com boletins conhecidos e conferir data, sete pares, orientação D/I, precisão, fatores e Application Log. Validar ausência de uma moeda sem impedir as demais e sem recuar a data.
6. Em DEV, provar criação, igualdade, atualização e reexecução pela BOI. Validar autorizações, locks, concorrência, erro em um par com preservação dos demais, mensagem de falha do job e reconciliação após resultado de commit incerto.
7. Após aceite operacional, configurar execução diária às 07:00 de Brasília, com datas vazias e simulação desmarcada. Coordenar a desativação do RPA para evitar manutenção concorrente.

Não foram executados nesta entrega: ativação SAP, ATC, ABAP Unit, gravação real de taxas, comunicação HTTPS do tenant ou agendamento produtivo. O template distribuído inicia em simulação.

## Governança

Especificação, plano, upload ao GitHub e ajuste de gravação por par foram aprovados pelo responsável. A dispensa do Harness formal SDD foi autorizada explicitamente para esta entrega de fontes, mantendo as verificações disponíveis e as pendências documentadas. Não há declaração de certificação formal SDD. Consulte [decisoes.md](decisoes.md).
