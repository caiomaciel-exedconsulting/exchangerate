# Comunicação e objetos de operação

Os fontes incluem o serviço outbound `ZEXED_PTAX_REST` (SCO3), o cenário `ZEXED_PTAX_COMM` (SCO1), o log `ZEXED_PTAX` (APLO), o catálogo `ZEXED_PTAX_JOB` (SAJC) e o template `ZEXED_PTAX_DAILY` (SAJT). Sistema e arrangement de comunicação são configuração de cada ambiente; não são criados pelo pull.

## Importação e publicação

Importar no pacote `ZEXED_FI_TAXA_CAMBIO`, componente `ZCUSTOM_DEVELOPMENT`. A configuração `.abapgit.xml` usa somente `/src/`, sem criar uma hierarquia adicional de pacotes.

Ativar o serviço outbound antes do cenário. Conferir no editor ADT que o cenário contém somente o serviço outbound HTTP `ZEXED_PTAX_REST`, sem serviços inbound e com autenticação outbound **Unauthenticated/None**. O XML deixa o cenário com publicação pendente (`PUBLISH_STATUS = u`); publicar localmente no ADT depois da conferência, para disponibilizá-lo no app Communication Arrangements. A serialização não comprova importação, ativação ou publicação no tenant.

O prefixo do serviço é `/olinda/servico/PTAX/versao/v1/odata`, sem barra final. No editor ele corresponde ao Default Path/Default URL do serviço vinculado ao cenário. O adapter habilita o prefixo e acrescenta `/CotacaoMoedaDia(...)` e os parâmetros de consulta. Não repetir o prefixo no caminho montado pelo adapter.

Se o importador instalado não reconhecer SCO1/SCO3 ou AFF, criar o objeto correspondente pelo editor ADT, preservando os nomes e os valores abaixo. Não renomear extensões ou tratar JSON AFF como um XML de outro serializer. Essa alternativa é uma configuração manual explícita, não uma confirmação de que o pull foi concluído.

## Configuração do acesso BACEN

1. No app **Communication Systems**, criar ou selecionar o sistema que representa o BACEN, por exemplo `ZBACEN_PTAX`. Configurar host `olinda.bcb.gov.br`, HTTPS e porta 443. Não colocar protocolo, caminho ou query no campo de host.
2. Manter outbound sem autenticação. Quando a interface exigir uma entrada de usuário outbound, usar o método **None**, conforme o suporte de comunicação sem autenticação do ambiente. O endpoint público PTAX não exige usuário/senha, client secret ou token.
3. No app **Communication Arrangements**, criar um arrangement para `ZEXED_PTAX_COMM`, selecionar o sistema e habilitar `ZEXED_PTAX_REST`.
4. Conferir o Path `/olinda/servico/PTAX/versao/v1/odata`, sem barra final, porta 443, HTTPS e autenticação **None**. Não colocar moeda/data nem a operação `CotacaoMoedaDia` no Path fixo.
5. Se houver mais de um sistema/arrangement aplicável, preencher `P_COMSYS` no job com o ID exato do sistema desejado. Sem esse parâmetro, a resolução precisa ser inequívoca. A classe usa `CL_HTTP_DESTINATION_PROVIDER=>CREATE_BY_COMM_ARRANGEMENT`, cenário `ZEXED_PTAX_COMM` e serviço `ZEXED_PTAX_REST`.
6. Validar TLS e acesso outbound a partir do próprio tenant. Uma consulta executada fora do SAP não comprova conectividade do job. Falha de configuração, TLS, HTTP ou JSON deve continuar sendo erro técnico, não ausência de boletim.

A composição esperada é `https://olinda.bcb.gov.br` + prefixo configurado + `/CotacaoMoedaDia(...)` + query. O resultado deve preservar exatamente uma ocorrência de `/olinda/servico/PTAX/versao/v1/odata`.

## Log, catálogo e template

Ativar `ZEXED_PTAX` com subobjeto `IMPORT`. Ativar a classe `ZCL_EXED_PTAX_JOB` antes do catálogo; ativar `ZEXED_PTAX_JOB` antes do template `ZEXED_PTAX_DAILY`.

Os parâmetros do catálogo correspondem aos atributos públicos da classe:

| Parâmetro | Default do template | Uso |
|---|---|---|
| `P_REFERENCE` | vazio | Data de referência; vazio usa a data corrente no fuso de negócio |
| `P_QUOTATION` | vazio | Data explícita da cotação para reprocessar; vazio calcula o dia útil anterior |
| `P_CALENDAR` | `BR` | ID legado do calendário de fábrica; validar mapeamento FHC e cobertura |
| `P_TIMEZONE` | `BRAZIL` | ID técnico SAP inicial para Brasília; confirmar sua existência e regras no tenant |
| `P_SIMULATE` | `X` | Simulação: consultar e comparar sem criar/alterar taxas ou drafts |
| `P_COMSYS` | vazio | ID do sistema de comunicação, quando necessário para resolver o arrangement |

O template não cria recorrência. Primeiro executar em simulação, conferir os sete pares e os logs, validar autorização e realizar os testes de escrita em DEV. Depois configurar a execução diária às **07:00 de Brasília**, inclusive fins de semana, com `P_REFERENCE` e `P_QUOTATION` vazios e simulação desmarcada. Conferir também o fuso do agendamento: alterar somente `P_TIMEZONE` não muda o fuso escolhido na tela de agendamento. O calendário controla a data consultada, não a periodicidade.

## Formatos e validação

APLO/SAJC/SAJT usam os schemas AFF v1 publicados pela SAP, com `abapLanguageVersion = cloudDevelopment`. SCO1/SCO3 usam o XML de serialização encontrado em exports dos exemplos oficiais SAP; não são JSON AFF. O abapGit open-source e o serviço abapGit usado por ADT em ABAP Cloud têm coberturas diferentes: a ausência desses serializers no primeiro não prova ausência de suporte no segundo. A compatibilidade efetiva permanece sujeita ao importador/release do tenant.

As verificações locais cobrem JSON/XML, campos previstos nos schemas AFF, referências cruzadas de nomes e defaults. Importação, ativação, publicação do cenário, resolução do destino, HTTPS do tenant e execução de job/log precisam de validação no SAP.

Fontes usadas para os formatos e a configuração:

- [Schemas oficiais SAP AFF: APLO](https://github.com/SAP/abap-file-formats/blob/4be8e14c2cfc3f7d9b4fbcc075dc1b257dc30f13/file-formats/aplo/aplo-v1.json), [SAJC](https://github.com/SAP/abap-file-formats/blob/4be8e14c2cfc3f7d9b4fbcc075dc1b257dc30f13/file-formats/sajc/sajc-v1.json) e [SAJT](https://github.com/SAP/abap-file-formats/blob/4be8e14c2cfc3f7d9b4fbcc075dc1b257dc30f13/file-formats/sajt/sajt-v1.json).
- [Export SAP de serviço SCO3](https://github.com/SAP-samples/abap-partner-reference-application/blob/53950acef763ac61dd610be8fc05fe6af98c247a/src/zpra_mf_service/zpra_mf_out_ent_proj_rest.sco3.xml) e [cenário SCO1](https://github.com/SAP-samples/abap-partner-reference-application/blob/53950acef763ac61dd610be8fc05fe6af98c247a/src/zpra_mf_service/zpra_mf_cs_ent_proj.sco1.xml). Foram usados os formatos; nenhum ID gerado de role, credencial, serviço ou configuração de autenticação desses exemplos foi reutilizado.
- [SAP: tipos suportados pelo abapGit em ABAP Environment](https://help.sap.com/docs/sap-btp-abap-environment/abap-environment/released-abap-object-types). Usado como referência de formato/importação Cloud, sem substituir a verificação do release Public Edition alvo.
- [SAP: cenários e autenticação outbound](https://help.sap.com/docs/abap-cloud/abap-integration-connectivity/communication-scenario) e [configuração sem autenticação](https://community.sap.com/t5/enterprise-resource-planning-blog-posts-by-sap/authenticating-at-internet-facing-services-via-outbound-communication-user/ba-p/13578965).

O campo `OB_NONE_AUTH` foi observado em [export público de cenário sem autenticação](https://github.com/javs12-87/zmarketrates/blob/d1a3e72b7011a3205198462df156aa0a7e809ee6/src/zbmx_get_rates.sco1.xml). Em leitura do tenant, seu elemento `APS_COM_CSCN_OB_NONE_AUTH` foi confirmado como flag CHAR de uma posição para suporte a comunicação outbound sem autenticação. Nenhum objeto de comunicação foi criado no tenant durante a preparação destes arquivos.
