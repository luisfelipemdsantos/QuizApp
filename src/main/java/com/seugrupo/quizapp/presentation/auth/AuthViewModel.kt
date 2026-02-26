package com.seugrupo.quizapp.presentation.auth
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.seugrupo.quizapp.domain.repository.AuthRepository
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.launch
sealed class AuthState { object Idle : AuthState(); object Loading : AuthState(); object Authenticated : AuthState(); data class Error(val message: String) : AuthState() }
class AuthViewModel(private val repository: AuthRepository) : ViewModel() {
    private val _state = MutableStateFlow<AuthState>(AuthState.Idle)
    val state: StateFlow<AuthState> = _state.asStateFlow()
    init { if (repository.isUserLoggedIn()) _state.value = AuthState.Authenticated }
    fun login(email: String, pass: String) = viewModelScope.launch {
        _state.value = AuthState.Loading
        val result = repository.loginWithEmail(email, pass)
        _state.value = if (result.isSuccess) AuthState.Authenticated else AuthState.Error(result.exceptionOrNull()?.message ?: "Erro")
    }
}