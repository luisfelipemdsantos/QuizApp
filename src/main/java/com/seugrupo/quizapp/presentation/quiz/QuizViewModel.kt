package com.seugrupo.quizapp.presentation.quiz
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.seugrupo.quizapp.domain.model.*
import com.seugrupo.quizapp.domain.repository.*
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.launch
sealed class QuizState { object Loading : QuizState(); data class Active(val questions: List<Question>, val currentIndex: Int, val score: Int) : QuizState(); data class Finished(val score: Int, val total: Int) : QuizState(); data class Error(val message: String) : QuizState() }
class QuizViewModel(private val quizRepository: QuizRepository, private val authRepository: AuthRepository) : ViewModel() {
    private val _state = MutableStateFlow<QuizState>(QuizState.Loading)
    val state: StateFlow<QuizState> = _state.asStateFlow()
    fun loadQuestions() = viewModelScope.launch {
        _state.value = QuizState.Loading
        quizRepository.syncQuestionsFromFirebase()
        val questions = quizRepository.getLocalQuestions()
        _state.value = if (questions.isNotEmpty()) QuizState.Active(questions, 0, 0) else QuizState.Error("Nenhuma pergunta encontrada.")
    }
    fun submitAnswer(selectedIndex: Int) {
        val currentState = _state.value
        if (currentState is QuizState.Active) {
            val isCorrect = selectedIndex == currentState.questions[currentState.currentIndex].correctOptionIndex
            val newScore = if (isCorrect) currentState.score + 1 else currentState.score
            if (currentState.currentIndex + 1 < currentState.questions.size) {
                _state.value = currentState.copy(currentIndex = currentState.currentIndex + 1, score = newScore)
            } else {
                viewModelScope.launch { authRepository.getCurrentUserId()?.let { quizRepository.saveQuizResult(QuizResult(userId = it, score = newScore, totalQuestions = currentState.questions.size)) } }
                _state.value = QuizState.Finished(newScore, currentState.questions.size)
            }
        }
    }
}