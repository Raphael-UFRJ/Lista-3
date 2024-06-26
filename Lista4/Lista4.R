library(igraph)
library(ggplot2)
library(plotly)
library(triangle)

# Tabela de dados corrigida
projeto <- data.frame(
  Atividade = 1:19,
  Descricao = c("Remove refractory material", "Repair inner air casing", "Repair outer air casing",
                "Repair under boiler", "Rebrick", "Chemically clean", "Remove air registers",
                "Install plastic refractory", "Repair air register assemblies", "Install air registers",
                "Rag for chemical cleaning", "Remove drum internals", "Repair drum internals",
                "Install drum internals", "Initial hydrostatic test", "Exploratory block",
                "Retube and poll", "Preliminary hydrostatic test", "Final hydrostatic test"),
  Pred = c("7,15", "1", "2", "-", "2,17", "11,17", "-", "10,19", "7", "5,9", "15", "15", "12", "13,18", "-", "1,12", "16", "6", "14"),
  DMin = c(4, 1, 1, 14, 5, 4, 0, 0.5, 10, 0.5, 5, 0.5, 5, 1, 1, 7, 4, 0, 0),
  DMp = c(5, 5, 5, 27, 6, 6, 0.5, 0.5, 10, 1, 6, 0.5, 12, 1.5, 2, 8, 6, 0, 0),
  DMax = c(10, 14, 10, 35, 14, 8, 3, 1, 20, 3, 7, 3, 18, 3, 5, 18, 12, 14, 3)
)

# Função para desenhar o grafo de precedência do projeto
q1 <- function(projeto) {
  # Converter os predecessores em uma lista de elos
  elos <- c()
  for (i in 1:nrow(projeto)) {
    preds <- unlist(strsplit(as.character(projeto$Pred[i]), ","))
    for (pred in preds) {
      if (pred != "-") {
        elos <- rbind(elos, c(as.numeric(pred), projeto$Atividade[i]))
      }
    }
  }
  
  # Criar o grafo com os elos
  g <- graph_from_edgelist(as.matrix(elos), directed = TRUE)
  
  # Identificar atividades iniciais e finais
  atividades_iniciais <- projeto$Atividade[projeto$Pred == "-"]
  preds <- unlist(strsplit(paste(projeto$Pred[projeto$Pred != "-"], collapse = ","), ","))
  atividades_finais <- projeto$Atividade[!projeto$Atividade %in% preds]
  
  # Definir cores para os vértices
  # vertex_colors <- rep("white", vcount(g))
  # names(vertex_colors) <- V(g)$name
  # vertex_colors[names(vertex_colors) %in% atividades_iniciais] <- "green"
  # vertex_colors[names(vertex_colors) %in% atividades_finais] <- "red"
  
  
  # Plotar o grafo
  tkplot(g, main = "Grafo de Precedência do Projeto", vertex.color = "white")
  return(g)
}


# Função para identificar as atividades iniciais e finais
q2 <- function(projeto) {
  # Identificar atividades iniciais (sem predecessores)
  atividades_iniciais <- projeto$Atividade[projeto$Pred == "-"]
  
  # Identificar atividades finais (não aparecem como predecessores)
  preds <- unlist(strsplit(paste(projeto$Pred[projeto$Pred != "-"], collapse = ","), ","))
  atividades_finais <- projeto$Atividade[!projeto$Atividade %in% preds]
  
  cat("Atividades Iniciais:", atividades_iniciais, "\n")
  cat("Atividades Finais:", atividades_finais, "\n")
}

# Função para gerar o grafo de precedência do caminho mais longo
q3 <- function(projeto) {
  elos <- c()
  for (i in 1:nrow(projeto)) {
    preds <- unlist(strsplit(as.character(projeto$Pred[i]), ","))
    for (pred in preds) {
      if (pred != "-") {
        elos <- rbind(elos, c(as.character(projeto$Atividade[as.numeric(pred)]), as.character(projeto$Atividade[i])))
      }
    }
  }
  
  g <- graph_from_edgelist(as.matrix(elos), directed = TRUE)
  
  # Calcular todos os caminhos mais longos
  caminhos_mais_longos <- get.all.shortest.paths(g, from = "7", to = as.character(nrow(projeto)), mode = "out")
  
  # Encontrar o caminho mais longo
  caminho_mais_longo <- caminhos_mais_longos$vpath[[which.max(sapply(caminhos_mais_longos$vpath, length))]]
  
  cat("Caminho Mais Longo:", caminho_mais_longo, "\n")
  
  # Criar um subgrafo com o caminho mais longo
  g_caminho_mais_longo <- induced_subgraph(g, caminho_mais_longo)
  
  tkplot(g_caminho_mais_longo, main = "Grafo do Caminho Mais Longo")
}


# Função para calcular aproximações empíricas para o risco de prazo da obra
q4 <- function(projeto) {
  cpm_result <- funcCpm(n = nrow(projeto), d = projeto$DMp, Suc = projeto$Atividade, Pre = projeto$Pred)
  projeto$TE <- cpm_result$est
  projeto$DesvioPadrao <- (cpm_result$lst - cpm_result$est) / 6
  projeto$Variancia <- projeto$DesvioPadrao^2
  
  cat("TE (Tempo Esperado):\n", projeto$TE, "\n")
  cat("Desvio Padrão:\n", projeto$DesvioPadrao, "\n")
  cat("Variância:\n", projeto$Variancia, "\n")
}

# Função para estimar as probabilidades das atividades pertencerem ao caminho crítico
q5 <- function(projeto) {
  cpm_result <- funcCpm(n = nrow(projeto), d = projeto$DMp, Suc = projeto$Atividade, Pre = projeto$Pred)
  caminho_critico <- which(cpm_result$est == cpm_result$lst)
  atividades_caminho_critico <- projeto$Atividade[caminho_critico]
  cat("Atividades no Caminho Crítico:", atividades_caminho_critico, "\n")
}

# Função para a distribuição de probabilidade da data de início mais cedo
q6 <- function(projeto) {
  cpm_result <- funcCpm(n = nrow(projeto), d = projeto$DMp, Suc = projeto$Atividade, Pre = projeto$Pred)
  cat("Data de Início Mais Cedo:", cpm_result$est, "\n")
}

q7 <- function(projeto, simulacoes = 1000) {
  # Inicializando Matriz e armazenando o resultado das simulações
  resultados <- matrix(nrow = simulacoes, ncol = nrow(projeto))
  
  # Rodando as simulações
  for (i in 1:simulacoes) {
    # Para cada atividade, rodamos a duração com base no minimo e maximo e medio.
    for (j in 1:nrow(projeto)) {
      resultados[i, j] <- rtriangle(1, projeto$DMin[j], projeto$DMp[j], projeto$DMax[j])
    }
  }
  
  # Calcula o percentil 85 para cada atividade
  duracao_percentil_85 <- apply(resultados, 2, function(x) quantile(x, probs = 0.85, na.rm = TRUE))
  
  # Atualiza a tabela do projeto com duração do percentil 85
  projeto$duracaoPercentil85 <- duracao_percentil_85
  
  # Cria o histograma
  ggplot(projeto, aes(x = duracaoPercentil85)) +
    geom_histogram(binwidth = 1, fill = "blue", color = "black") +
    theme_minimal() +
    labs(title = "Histogram with Monte Carlo Simulation", x = "85th Percentile Duration", y = "Frequency")
}

# Função para criar um diagrama de Gantt
q8 <- function(projeto) {
  cpm_result <- funcCpm(n = nrow(projeto), d = projeto$DMp, Suc = projeto$Atividade, Pre = projeto$Pred)
  projeto$TE <- cpm_result$est
  ggplot(projeto, aes(x = Atividade, y = TE, fill = Descrição)) +
    geom_bar(stat = "identity") +
    theme_minimal() +
    labs(title = "Diagrama de Gantt", x = "Atividade", y = "Tempo Esperado (TE)") +
    coord_flip()
}


# Função para criar um diagrama de Gantt usando Plotly
q8_plotly <- function(projeto) {
  projeto$TE <- (projeto$DMin + 4*projeto$DMp + projeto$DMax) / 6
  
  fig <- plot_ly(projeto, x = ~TE, y = ~Atividade, type = 'bar', orientation = 'h',
                 marker = list(color = 'rgba(50, 171, 96, 0.6)',
                               line = list(color = 'rgba(50, 171, 96, 1.0)', width = 1)))
  fig <- fig %>% layout(title = "Diagrama de Gantt com Plotly",
                        xaxis = list(title = "Tempo Esperado (TE)"),
                        yaxis = list(title = "Atividade"))
  
  fig
}

# Chamadas de função para testar
q1(projeto)
#g <- q1(projeto)
q2(projeto)
q3(projeto) # Estadando resultado errado
q4(projeto)
q5(projeto) # Requer análise detalhada
q6(projeto) # Requer análise de rede
q7(projeto) # Requer simulação
q8(projeto)
q8_plotly(projeto)
