package com.seugrupo.quizapp.presentation

import androidx.compose.runtime.*
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.compose.*
import com.seugrupo.quizapp.presentation.auth.*
import com.seugrupo.quizapp.presentation.home.*
import com.seugrupo.quizapp.presentation.quiz.*
import com.seugrupo.quizapp.presentation.history.*
import com.seugrupo.quizapp.presentation.ranking.*

@Composable
fun AppNavigation(viewModelFactory: AppViewModelFactory) {
    val navController = rememberNavController()
    val authViewModel: AuthViewModel = viewModel(factory = viewModelFactory)
    val authState by authViewModel.state.collectAsState()

    NavHost(navController = navController, startDestination = if (authState is AuthState.Authenticated) "home" else "login") {
        composable("login") {
            val viewModel: AppViewModel = viewModel(factory = viewModelFactory)
            LoginScreen(
                viewModel = viewModel,
                onLoginSuccess = { navController.navigate("home") { popUpTo("login") { inclusive = true } } },
                onNavigateToRegister = { navController.navigate("register") }
            )
        }
        composable("register") {
            val viewModel: AppViewModel = viewModel(factory = viewModelFactory)
            RegisterScreen(
                viewModel = viewModel,
                onRegisterSuccess = { navController.navigate("home") { popUpTo("login") { inclusive = true } } },
                onBackToLogin = { navController.popBackStack() }
            )
        }
        composable("home") {
            val viewModel: AppViewModel = viewModel(factory = viewModelFactory)
            HomeScreen(
                onStartQuiz = { navController.navigate("quiz") },
                onViewHistory = { navController.navigate("history") },
                onViewRanking = { navController.navigate("ranking") }, // NOVO PARÂMETRO
                onLogout = {
                    viewModel.logout()
                    navController.navigate("login") { popUpTo("home") { inclusive = true } }
                }
            )
        }
        composable("quiz") { QuizScreen(viewModel = viewModel(factory = viewModelFactory)) { navController.popBackStack() } }
        composable("history") { HistoryScreen(viewModel = viewModel(factory = viewModelFactory)) { navController.popBackStack() } }
        composable("ranking") { RankingScreen(viewModel = viewModel(factory = viewModelFactory)) { navController.popBackStack() } } // NOVA ROTA
    }
}
