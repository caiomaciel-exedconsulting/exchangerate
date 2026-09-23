# Autorizações para acessar e executar o job PTAX

O roteiro inicial omitiu a configuração de acesso do usuário. Ativar os objetos e passar em ATC/ABAP Unit não conclui essa etapa. O responsável posteriormente exportou o catálogo `ZEXED_PTAX` e a atribuição `ZEXED_PTAX_0001` no commit `163a64c` e iniciou uma execução do job. As etapas abaixo permanecem como roteiro para novos ambientes; os nomes sugeridos não exigem criar um segundo catálogo.

## Objetos e vínculos

| Elemento | Identificador | Situação |
|---|---|---|
| Catálogo de job (SAJC) | `ZEXED_PTAX_JOB` | Incluído nos fontes |
| Template de job (SAJT) | `ZEXED_PTAX_DAILY` | Incluído nos fontes |
| IAM App de autorização de início | `ZEXED_PTAX_JOB_SAJC` | Nome informado pelo responsável; gerada a partir do catálogo de job |
| Business Catalog IAM | `ZEXED_PTAX` | Exportado pelo responsável; `ZEXED_BC_PTAX` abaixo é apenas o exemplo original |
| Business Role | `ZEXED_BR_PTAX` | Nome sugerido para criação no Fiori; pode ser substituído por role existente apropriada |
| Business User | Usuário que agendará/executará o job | Atribuir a role no ambiente |

O catálogo SAJC descreve o job. O Business Catalog IAM agrupa as autorizações atribuídas pela Business Role ao usuário. São objetos distintos.

## 1. Criar e publicar o Business Catalog no ADT

1. No pacote `ZEXED_FI_TAXA_CAMBIO`, escolher **New → Other ABAP Repository Object → Cloud Identity and Access Management → Business Catalog**.
2. Informar, por exemplo, `ZEXED_BC_PTAX`, descrição **Importação de taxas de câmbio PTAX**, e selecionar a ordem de transporte aplicável.
3. Na aba **Apps**, escolher **Add…** e selecionar a IAM App existente `ZEXED_PTAX_JOB_SAJC`. Concluir a criação da atribuição e salvar os objetos.
4. No Business Catalog, executar **Publish Locally** para disponibilizá-lo no ambiente de desenvolvimento. Conferir eventuais mensagens de ativação/publicação.

O exemplo oficial SAP mostra essa associação de uma IAM App com sufixo `_SAJC` e a publicação do catálogo: [Build a Custom Process Based on Standard Business Objects, seção “Creating a business catalog and assigning IAM apps”](https://help.sap.com/doc/b259ccf0894142cca88950f661a56103/SHIP/en-US/Build_a_Custom_Process_Based_on_Standard_Business_Objects.pdf).

## 2. Criar a Business Role e atribuir ao usuário

1. No Fiori, abrir **Maintain Business Roles** e criar ou editar a role escolhida, por exemplo `ZEXED_BR_PTAX`.
2. Em **Assigned Business Catalogs**, adicionar o catálogo publicado na etapa anterior.
3. Conferir as restrições aplicáveis e salvar. Atribuir a role ao Business User que fará o agendamento, usando a administração de usuários/roles.
4. Conferir também o acesso ao app **Application Jobs**. Caso ainda não exista por outra role, incluir `SAP_CORE_BC_APJ_JCE` na role apropriada. A autorização do job customizado e o acesso ao app precisam estar presentes.

A SAP descreve a geração da IAM App, a cadeia catálogo/role/usuário e o catálogo do app em [Configuração das autorizações — Developer Extensibility, Public Edition](https://help.sap.com/docs/SAP_S4HANA_CLOUD/6aa39f1ac05441e5a23f484f31e477e7/bb559a5a4b654996a167d72273f28542.html?locale=pt-BR&version=2602.500). As restrições de acesso a jobs de outros usuários estão descritas em [Atualização de autorizações](https://help.sap.com/docs/SAP_S4HANA_CLOUD/a630d57fc5004c6383e7a81efee7a8bb/171039b7300345cb81392ba058db5dd4.html?locale=pt-BR).

Permissões para consultar jobs/logs de outros usuários ou agendar em nome deles dependem de restrições adicionais. Configurá-las somente se fizerem parte da operação prevista. A autorização de início do job também não substitui as autorizações de negócio exigidas para manter taxas pela BOI; validar a execução com o usuário previsto.

## 3. Validar o acesso antes da operação

- Atualizar a sessão do usuário após a atribuição e abrir **Application Jobs**.
- Criar um agendamento e localizar o template `ZEXED_PTAX_DAILY` pela descrição de importação PTAX.
- Executar em simulação (`P_SIMULATE = X`) e conferir resultados e Application Log, conforme [comunicacao.md](comunicacao.md).
- Se o app não aparecer, revisar o acesso ao app; se o app abrir mas o template não aparecer, revisar a IAM App, sua atribuição, publicação do catálogo, role e usuário. Conferir também a ativação do SAJC/SAJT.

## Repositório e configuração do ambiente

O assistente não criou catálogo, role ou vínculo de usuário no tenant. O responsável versionou o Business Catalog `ZEXED_PTAX` e sua atribuição em arquivos SIA1/SIA7. Business Role e atribuição ao usuário devem ser mantidas no ambiente; o pull desses fontes não configura automaticamente esses vínculos.

**Publish Locally** disponibiliza o catálogo no desenvolvimento; para outros ambientes, seguir o processo de transporte e configuração correspondente.

Critério operacional: o usuário previsto consegue abrir o app, selecionar o template, executar uma simulação e consultar o log. A manutenção real de taxas e a recorrência diária seguem as verificações de [validacao.md](validacao.md).
