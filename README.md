# EcoWallet App

Ecossistema mobile inteligente focado em impacto socioambiental positivo, finanças pessoais sustentáveis e integração com inteligência artificial.

Projeto selecionado, validado e acelerado internacionalmente entre os 100 finalistas do programa de empreendedorismo Santander X Explorer.

---

## Sobre o EcoWallet

O EcoWallet une tecnologia e engenharia de software para apoiar a transição para uma economia de baixo carbono. O aplicativo combina o monitoramento de despesas financeiras a critérios rígidos de ESG, ajudando usuários a tomarem decisões de consumo mais conscientes através de gamificação e dados mensuráveis.

### Funcionalidades Principais

* Gestão Inteligente de Gastos: Monitoramento de transações financeiras associado ao cálculo automatizado de pegada de carbono.
* Recompensas Eco: Sistema de gamificação estruturado para engajar o usuário, gerando pontos e prêmios por hábitos sustentáveis no dia a dia.
* EcoBot: Assistente virtual inteligente integrado para consultas ecológicas e financeiras em tempo real, fornecendo insights personalizados baseados em IA.

---

## Arquitetura e Engenharia de Software

O ecossistema foi projetado com foco em escalabilidade, testabilidade e manutenibilidade, separando as responsabilidades de software de acordo com as boas práticas de desenvolvimento mobile.

### Padrão Arquitetural: Clean Architecture
A estrutura do projeto está organizada de forma modular dentro do diretório lib:
* app/: Configurações globais do sistema, temas e rotas.
* features/: Funcionalidades isoladas de negócio, contendo as views e componentes de interface.
* repositories/: Camada de dados responsável por gerenciar a origem das informações, abstraindo consumos de APIs externas e locais.
* src/: Núcleo de regras e lógicas compartilhadas do app.

### Gerenciamento de Estado Avançado
Para manter a interface puramente reativa e isolada das regras de negócio, o projeto utiliza o padrão BLoC / Cubit através do pacote flutter_bloc. Isso garante um fluxo de dados unidirecional, previsível e testável com o suporte de ferramentas como bloc_test.

### Principais Tecnologias e Dependências
* Framework Principal: Flutter e Dart
* Gerenciamento de Estado: flutter_bloc (^8.1.3)
* Persistência de Dados Local: shared_preferences (^2.5.3)
* Testes de Estado: bloc_test (^9.1.5)
* Segurança: Gerenciamento de credenciais e chaves via variáveis de ambiente (.env)
* Automações e IA: Integrações assíncronas via Webhooks de LLM e automação de fluxos de trabalho através do n8n.

---

## Como Executar o Projeto Localmente

### Pré-requisitos
Certifique-se de ter o Flutter SDK instalado e configurado na sua máquina.

1. Clonar o repositório:
git clone https://github.com

2. Entrar na pasta do projeto:
cd ecowallet_app

3. Instalar as dependências do Flutter:
flutter pub get

4. Configurar as Variáveis de Ambiente:
Crie um arquivo .env na raiz do projeto seguindo o modelo de chaves necessárias para a comunicação com os serviços de IA e automação externa.

5. Executar o aplicativo:
flutter run

---

## Desenvolvedor

* Fabio Coelho Moura - Idealizador e Engenheiro de Software Mobile
* LinkedIn: ://linkedin.com
* GitHub: ://github.com
