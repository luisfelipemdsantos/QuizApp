package com.seugrupo.quizapp.presentation.home
import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ExitToApp
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
// ... (imports existentes)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HomeScreen(onStartQuiz: () -> Unit, onViewHistory: () -> Unit, onViewRanking: () -> Unit, onLogout: () -> Unit) { // NOVO PARÂMETRO
    Scaffold(topBar = { TopAppBar(title = { Text("Dashboard") }, actions = { IconButton(onClick = onLogout) { Icon(Icons.Default.ExitToApp, "Sair") } }) }) { paddingValues ->
        Column(modifier = Modifier.fillMaxSize().padding(paddingValues).padding(24.dp), verticalArrangement = Arrangement.Center, horizontalAlignment = Alignment.CenterHorizontally) {
            Card(modifier = Modifier.fillMaxWidth(), elevation = CardDefaults.cardElevation(defaultElevation = 4.dp)) {
                Column(modifier = Modifier.padding(24.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                    Text("Bem-vindo!", style = MaterialTheme.typography.titleLarge)
                    Spacer(Modifier.height(24.dp))
                    Button(onClick = onStartQuiz, modifier = Modifier.fillMaxWidth()) { Text("Iniciar Novo Quiz") }
                    Spacer(Modifier.height(16.dp))
                    OutlinedButton(onClick = onViewHistory, modifier = Modifier.fillMaxWidth()) { Text("Ver Meu Histórico") }
                    Spacer(Modifier.height(16.dp))
                    OutlinedButton(onClick = onViewRanking, modifier = Modifier.fillMaxWidth()) { Text("Ver Ranking Global") } // NOVO BOTÃO
                }
            }
        }
    }
}