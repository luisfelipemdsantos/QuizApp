package com.seugrupo.quizapp.presentation.quiz

import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun QuizScreen(viewModel: QuizViewModel, onQuizFinished: () -> Unit) {
    val state by viewModel.state.collectAsState()
    LaunchedEffect(Unit) { viewModel.loadQuestions() }

    Scaffold(topBar = { TopAppBar(title = { Text("A Jogar") }) }) { padding ->
        Box(modifier = Modifier.padding(padding).fillMaxSize(), contentAlignment = Alignment.Center) {
            when (val currentState = state) {
                is QuizState.Loading -> CircularProgressIndicator()
                is QuizState.Error -> Text("Erro: ${currentState.message}")
                is QuizState.Finished -> {
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        Text("Fim do Quiz!", style = MaterialTheme.typography.headlineMedium)
                        Text(
                            "Pontuação: ${currentState.score} de ${currentState.total}",
                            style = MaterialTheme.typography.titleLarge,
                            modifier = Modifier.padding(vertical = 8.dp)
                        )
                        Button(onClick = onQuizFinished) { Text("Voltar") }
                    }
                }
                is QuizState.Active -> {
                    Column(
                        modifier = Modifier.padding(24.dp).fillMaxSize(),
                        horizontalAlignment = Alignment.CenterHorizontally
                    ) {
                        val question = currentState.questions[currentState.currentIndex]
                        Text("Pergunta ${currentState.currentIndex + 1} de ${currentState.questions.size}")
                        Text(
                            question.text,
                            style = MaterialTheme.typography.headlineSmall,
                            modifier = Modifier.padding(vertical = 16.dp)
                        )
                        question.options.forEachIndexed { index, option ->
                            OutlinedButton(
                                onClick = { viewModel.submitAnswer(index) },
                                modifier = Modifier.fillMaxWidth().padding(vertical = 4.dp)
                            ) {
                                Text(option)
                            }
                        }
                    }
                }
            }
        }
    }
}