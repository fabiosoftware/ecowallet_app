# EcoWallet — Algoritmo de Carbon Scoring

Implementação: [`CarbonScoringRepository`](lib/repositories/carbon_score_repository.dart)
Testes: [`carbon_scoring_repository_test.dart`](test/carbon_scoring_repository_test.dart)

> Os fatores abaixo são **estimativas de produto para gamificação**, não um
> inventário de emissões. Antes de qualquer divulgação externa, é preciso
> documentar fonte, fronteira e incerteza de cada fator (ver
> [ESG_FRAMEWORK.md](ESG_FRAMEWORK.md)).

## Visão geral

A cada operação (gasto ou reciclagem), o app calcula a **variação de pontos
verdes** e a soma ao saldo do usuário.

```text
entrada ──► sanitização ──► emissão gerada (kg)    ─┐
                      └──► mitigação (kg, c/ teto) ─┴─► variação de pontos
saldo novo = max(0, round(saldo atual + variação))
```

## 1. Variação de pontos (`calculateNewPoints`, função pura)

```text
gerada   = valor × fatorEmissão(categoria)
mitigada = min(50, valor × fatorGastoSustentável(categoria)
                 + peso × fatorMaterial(material))
pontos   = mitigada × 10 − gerada × 2
```

| Hábito | Entrada | Fator | Efeito |
| --- | --- | --- | --- |
| Combustível | R$ gasto, `combustivel` | 0,15 kg CO₂/R$ | Emissão (penaliza) |
| Alimentação | R$ gasto, `alimentacao` | 0,04 kg CO₂/R$ | Emissão (penaliza) |
| Reciclar alumínio | kg, `aluminio` | 8,5 kg CO₂ evitado/kg | Mitigação |
| Reciclar plástico | kg, `plastico` | 1,5 kg CO₂ evitado/kg | Mitigação |
| Reciclar papel | kg, `papel` | 0,9 kg CO₂ evitado/kg | Mitigação |
| Compras ecológicas | R$ gasto, `gasto_sustentavel` | 0,5 kg CO₂/R$ | Mitigação |

Regras:

- **Sanitização:** valores negativos, `NaN` e infinitos viram `0`.
- **Normalização de texto:** minúsculas, sem espaços nas pontas e sem acentos
  (`" Alimentação "` → `alimentacao`).
- **Desconhecidos:** categoria ou material sem fator contribuem com `0`.
- **Teto antifraude:** a mitigação é limitada a **50 kg por chamada**
  (máximo de +500 pontos). O teto **não** se aplica à emissão.
- Emissão pesa ×2 e mitigação ×10, priorizando a recompensa de bons hábitos.

### Exemplos

| Cenário | Cálculo | Pontos |
| --- | --- | --- |
| R$ 100 em combustível | −(100 × 0,15 × 2) | −30 |
| 2 kg de papel | 2 × 0,9 × 10 | +18 |
| R$ 100 combustível + 4 kg plástico | 60 − 30 | +30 |
| 100 kg de alumínio | min(850, 50) × 10 | +500 |

## 2. Atualização do saldo (`calculateUpdatedScore`)

`round(max(0, atual) + variação)`; resultado não finito ou ≤ 0 retorna `0`.
O saldo é inteiro porque o painel lê `greenPointsEarned` como `int` e nunca é
negativo.

## 3. Persistência (`updateCarbonScore`)

- Documento `carbon_scores/score_{uid}` com `userId` do dono.
- Leitura + escrita dentro de `runTransaction`, evitando perda de atualização
  em operações concorrentes.
- `carbonFootprintKg` acumula apenas a emissão gerada.
- Sem usuário autenticado lança `StateError`.

## Cobertura de testes

A suíte cobre a lógica pura: cada fator, normalização, entradas inválidas,
limites do teto (49/50/51 kg), combinação emissão + mitigação, arredondamento
e saldo mínimo zero.

**Não coberto automaticamente:** `updateCarbonScore` (transação no Firestore)
exige um fake/emulador de Firestore, que não está nas dependências do projeto.

## Limitações conhecidas e evolução

- **Transporte sustentável** (bicicleta, transporte público, carona) ainda
  **não tem fator**. Falta definir fonte e unidade (kg CO₂ evitado por km ou
  por R$) antes de incluí-lo; ao definir, adicione o fator aos mapas de
  mitigação com testes equivalentes.
- O teto é por chamada; não há limite diário/mensal.
- `gasto sustentavel` (com espaço) não equivale a `gasto_sustentavel`.
- Fatores e multiplicadores precisam de versão da metodologia para auditoria.
