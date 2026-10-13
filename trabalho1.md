## 📋 Trabalho 1: Plataforma Web IFBet (Python + Flask + Jinja + Psycopg)

A aplicação consiste em um sistema web onde o Flask processa as rotas HTTP, interage diretamente com o PostgreSQL através do driver Psycopg (sem ORM) e renderiza as interfaces dinâmicas utilizando arquivos de template do Jinja.

------------------------------
## ⚙️ Funcionalidades e Distribuição de Pontos## 1. Painel do Apostador: Listagem de Jogos e Estatísticas (GET /dashboard) — [Valor: 1,5 Pontos]

* Interface Web (Jinja): Uma página que exibe as boas-vindas a um usuário (selecionado por um parâmetro de ID na URL), o seu saldo atual, a lista de jogos disponíveis e um resumo das estatísticas gerais do sistema.
* Processamento e Banco (Psycopg/Postgres):
* O sistema executa queries nativas utilizando as funções do banco: obter_saldo(usuario_id) para trazer o dinheiro do cliente e liste_jogos() para carregar as partidas na tela.
   * Para o rodapé ou barra lateral de estatísticas, o sistema deve chamar e exibir os retornos das funções total_jogos() e media_valor_apostas(). Todas as variáveis coletadas devem ser repassadas para renderização no template Jinja.

## 2. Execução de Palpite: Nova Aposta Automática (POST /apostar) — [Valor: 2,0 Pontos]

* Interface Web (Jinja): Ao lado de cada jogo listado no painel, deve existir um formulário simples contendo um campo de texto para o usuário digitar o valor em dinheiro e um botão "Apostar".
* Processamento e Banco (Psycopg/Postgres):
* Ao enviar o formulário, a rota recebe o ID do usuário, o ID do jogo escolhido e o valor do palpite.
   * O código Python abre uma transação via Psycopg e invoca diretamente a procedure propor_aposta(usuario_id, jogo_id, valor) do banco de dados utilizando o comando SELECT propor_aposta(%s, %s, %s).
   * O sistema captura o retorno booleano da função do Postgres: se for True (aposta realizada e saldo atualizado), redireciona o usuário de volta ao painel exibindo uma mensagem de sucesso; se for False, retorna um aviso de "saldo insuficiente".

## 3. Histórico de Bilhetes e Lucro Potencial (GET /meus-bilhetes) — [Valor: 1,5 Pontos]

* Interface Web (Jinja): Uma página dedicada a listar todos os bilhetes de apostas já realizados pelo usuário ativo, organizados em uma tabela com o lucro projetado de cada um.
* Processamento e Banco (Psycopg/Postgres):
* A rota captura o ID do usuário e faz uma chamada à função do banco apostas_usuario(usuario_id) para listar os identificadores das apostas, valores e odds associadas.
   * Para cada aposta retornada, o sistema realiza uma subconsulta utilizando a função lucro_potencial(aposta_id) para resgatar o cálculo matemático do retorno financeiro feito diretamente pelo Postgres, injetando os dados finais na tabela HTML processada pelo Jinja.


