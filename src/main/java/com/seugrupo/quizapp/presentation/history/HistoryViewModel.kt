package com.seugrupo.quizapp.presentation.history
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.seugrupo.quizapp.domain.model.QuizResult
import com.seugrupo.quizapp.domain.repository.*
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.launch
import java.text.SimpleDateFormat
import java.util.*
class HistoryViewModel(private val quizRepository: QuizRepository, private val authRepository: AuthRepository) : ViewModel() {
    private val _history = MutableStateFlow<List<QuizResult>>(emptyList())
    val history: StateFlow<List<QuizResult>> = _history.asStateFlow()
    init { viewModelScope.launch { authRepository.getCurrentUserId()?.let { _history.value = quizRepository.getUserHistory(it) } } }
    fun formatDate(timestamp: Long): String = SimpleDateFormat("dd/MM/yyyy HH:mm", Locale.getDefault()).format(Date(timestamp))
}