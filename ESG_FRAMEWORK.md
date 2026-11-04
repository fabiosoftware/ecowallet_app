# EcoWallet — Framework de alinhamento ESG

## Objetivo e escopo

Este documento descreve como os recursos atuais do EcoWallet podem apoiar a
gestão e a comunicação de temas ambientais, sociais e de governança (ESG).
Serve como orientação de produto e não como declaração de conformidade,
asseguração independente ou certificação. A aplicação, por si só, não comprova
impacto ambiental, desempenho social ou conformidade regulatória.

As referências globais abaixo são pontos de alinhamento para orientar a
evolução do produto. O uso de indicadores ESG em relatórios corporativos exige
definições, limites, evidências e controles apropriados à organização que os
publica.

## Visão geral dos pilares

| Pilar | Recurso do EcoWallet | Contribuição potencial |
| --- | --- | --- |
| Ambiental | Pontuação de carbono e pontos verdes em `CarbonScoreRepository` | Tornar visíveis estimativas de pegada e incentivar escolhas de menor impacto. |
| Social | Pontos, histórico e recompensas em `EcoRewardsDashboardPage` | Incentivar participação e hábitos sustentáveis por meio de gamificação. |
| Governança | Registros de despesas e pontuações no Firebase Cloud Firestore | Manter registros consultáveis associados a transações para dar suporte à rastreabilidade. |

## 1. Ambiental — Carbon Scoring

### Implementação atual

O modelo `CarbonScoreModel` representa cada pontuação com:

- `transactionId`: identificador da transação relacionada;
- `carbonFootprintKg`: estimativa de pegada em quilogramas de CO₂ equivalente
  (o nome do campo é genérico; a unidade e o uso de CO₂e devem ser confirmados
  pela metodologia adotada);
- `greenPointsEarned`: pontos verdes atribuídos;
- `timestamp`: data e hora da pontuação.

O `CarbonScoreRepository` grava e consulta documentos na coleção
`carbon_scores`, ordena o fluxo de pontuações pelo campo `timestamp` e soma os
pontos verdes para o chatbot. A interface de recompensas exibe as pontuações e
o histórico recente.

### Alinhamento de referência

- **GHG Protocol**: fornece princípios e métodos para contabilizar emissões de
  gases de efeito estufa. Uma pontuação do aplicativo só deve ser apresentada
  como estimativa indicativa até que fatores de emissão, fronteiras, período,
  fontes de dados e tratamento de incerteza sejam documentados.
- **GRI 305 (Emissões)** e **IFRS S2 (divulgações relacionadas ao clima)**:
  podem orientar a organização na definição de divulgações climáticas e de
  métricas. Dados de uma transação individual no EcoWallet não substituem o
  inventário de emissões nem as divulgações exigidas de uma entidade.
- **ODS 12 (Consumo e produção responsáveis) e ODS 13 (Ação climática)**:
  oferecem contexto para iniciativas de conscientização e mudança de hábitos;
  não constituem, por si só, validação de impacto.

### Controles e evolução recomendados

1. Documentar metodologia, fatores de emissão e fonte, categorias cobertas,
   unidade (preferencialmente CO₂e quando aplicável), período e limitações.
2. Diferenciar valores medidos de estimados e evitar atribuir redução de
   emissões sem comparação de referência verificável.
3. Registrar versão da metodologia e origem dos dados para que uma pontuação
   possa ser reproduzida e auditada.
4. Validar faixas, valores ausentes e conversões numéricas antes de usar os
   dados em indicadores ou relatórios.

## 2. Social — Gamificação e EcoRewards

### Implementação atual

`EcoRewardsDashboardPage` soma os `greenPointsEarned`, mostra o saldo e as
transações ecológicas mais recentes e apresenta opções de recompensa. O saldo
é derivado dos documentos recebidos pelo fluxo do repositório. A ação de
resgate atualmente verifica se há pontos suficientes, pede confirmação e
mostra uma mensagem; não persiste o resgate nem deduz pontos do saldo.

### Alinhamento de referência

- **GRI 3 (Temas materiais) e GRI 413 (Comunidades locais)** podem ajudar a
  estruturar a avaliação de impactos e o diálogo com partes interessadas,
  quando aplicável ao contexto da organização.
- **IFRS S1** orienta divulgações sobre riscos e oportunidades relacionados à
  sustentabilidade que possam afetar as perspectivas da entidade. A
  gamificação é um mecanismo de engajamento, não uma métrica de desempenho
  social por si só.
- **ODS 10 (Redução das desigualdades), ODS 11 (Cidades e comunidades
  sustentáveis) e ODS 12** podem servir como referências para avaliar
  acessibilidade, mobilidade e consumo responsável.

### Controles e evolução recomendados

1. Tornar transparentes as regras de pontuação e os requisitos de elegibilidade
   para evitar incentivos ambíguos ou injustos.
2. Verificar acessibilidade, linguagem e disponibilidade das recompensas para
   diferentes perfis de usuários; oferecer alternativas para quem não consegue
   realizar determinadas atividades.
3. Se o resgate passar a ser efetivo, implementar registro persistente,
   confirmação idempotente, débito atômico de pontos e histórico de resgates.
4. Medir participação e conclusão de ações com dados agregados e minimizados,
   sem inferir benefícios sociais ou mudanças de comportamento sem evidência.

## 3. Governança — Rastreabilidade no Firebase

### Implementação atual

`FirestoreExpenseRepository` armazena despesas em
`users/{uid}/expenses`, identificando o usuário autenticado e registrando
valor, categoria, descrição e data. O cache local do Firestore pode manter
escritas pendentes até a sincronização.

`CarbonScoreRepository` usa `transactionId` como identificador do documento
em `carbon_scores` e grava os campos de `CarbonScoreModel`. O fluxo de consulta
ordena os registros pelo timestamp. No código atual, esses documentos de
pontuação ficam numa coleção de nível superior; o modelo não contém `userId`.
Portanto, a associação entre pontuação, usuário e despesa não deve ser
considerada garantida apenas pelo identificador da transação.

### Alinhamento de referência

- **GRI 2 (Divulgações gerais)** e **IFRS S1** podem orientar responsabilidades,
  processos de governança e controles usados para supervisionar informações
  de sustentabilidade.
- Princípios de integridade, rastreabilidade e prestação de contas exigem
  evidências consistentes e controles proporcionais ao risco. Um documento
  Firestore editável não é, por si só, um registro imutável nem uma trilha de
  auditoria completa.
- Proteção de dados deve considerar as leis aplicáveis, incluindo a LGPD no
  Brasil, e princípios de minimização, finalidade, transparência e segurança.

### Controles e evolução recomendados

1. Definir regras de segurança do Firestore para autenticação, autorização por
   usuário e validação de campos; testar essas regras antes de produção.
2. Vincular cada pontuação ao usuário e à transação correspondente, ou usar um
   caminho de documentos que imponha essa relação, restringindo leitura e
   escrita ao proprietário autorizado.
3. Definir política de retenção, correção e exclusão, controles de acesso
   administrativo, monitoramento e resposta a incidentes.
4. Se forem necessários registros de auditoria, manter eventos de alteração
   apropriados, com identidade do ator, instante, motivo e controles contra
   alterações não autorizadas. Não apresentar a coleção atual como imutável.
5. Documentar a origem dos dados e o processo de reconciliação entre despesas,
   pontuações e recompensas; monitorar falhas de sincronização e inconsistências.

## Indicadores sugeridos

Os indicadores abaixo são sugestões para avaliação do produto, não valores
medidos ou resultados atualmente garantidos pelo EcoWallet:

| Pilar | Indicador a definir | Evidência necessária |
| --- | --- | --- |
| Ambiental | Pontuações calculadas por período e categoria; distribuição das estimativas de CO₂e | Metodologia versionada, fatores de emissão e dados de origem. |
| Social | Usuários participantes, ações concluídas e resgates efetivamente processados | Definições consistentes, registro de resgates e métricas agregadas que respeitem a privacidade. |
| Governança | Registros vinculados a usuário/transação; falhas de validação e sincronização; revisões de acesso | Regras Firestore testadas, logs operacionais e processo de auditoria documentado. |

## Limitações e comunicação responsável

- Não anunciar o EcoWallet como certificado, auditado ou em conformidade com
  GRI, IFRS, GHG Protocol ou qualquer norma apenas por possuir estas
  funcionalidades.
- Identificar estimativas como estimativas, explicar limitações e evitar
  somá-las como reduções corporativas verificadas.
- Revisar as regras do Firebase, o modelo de dados, a metodologia ambiental e
  os fluxos de recompensa antes de usar dados em relatórios externos.
- Reavaliar este documento sempre que a metodologia de pontuação, a
  persistência de resgates ou as regras de acesso a dados forem alteradas.
