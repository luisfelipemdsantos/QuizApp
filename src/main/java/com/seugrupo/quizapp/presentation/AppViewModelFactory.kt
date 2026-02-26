package com.seugrupo.quizapp.presentation
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import com.seugrupo.quizapp.domain.repository.*
import com.seugrupo.quizapp.presentation.auth.AuthViewModel
import com.seugrupo.quizapp.presentation.history.HistoryViewModel
import com.seugrupo.quizapp.presentation.quiz.QuizViewModel
import com.seugrupo.quizapp.presentation.ranking.RankingViewModel // IMPORTADO

class AppViewModelFactory(private val authRepository: AuthRepository, private val quizRepository: QuizRepository) : ViewModelProvider.Factory {
    override fun <T : ViewModel> create(modelClass: Class<T>): T {
        if (modelClass.isAssignableFrom(AuthViewModel::class.java)) return AuthViewModel(authRepository) as T
        if (modelClass.isAssignableFrom(QuizViewModel::class.java)) return QuizViewModel(quizRepository, authRepository) as T
        if (modelClass.isAssignableFrom(HistoryViewModel::class.java)) return HistoryViewModel(quizRepository, authRepository) as T
        if (modelClass.isAssignableFrom(AppViewModel::class.java)) return AppViewModel(authRepository, quizRepository) as T
        if (modelClass.isAssignableFrom(RankingViewModel::class.java)) return RankingViewModel(quizRepository) as T // ADICIONADO
        throw IllegalArgumentException("Classe desconhecida")
    }
}