package com.seugrupo.quizapp.presentation

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.seugrupo.quizapp.domain.repository.AuthRepository
import com.seugrupo.quizapp.domain.repository.QuizRepository
import kotlinx.coroutines.launch

class AppViewModel(
    private val authRepository: AuthRepository,
    private val quizRepository: QuizRepository
) : ViewModel() {

    fun isUserLoggedIn(): Boolean {
        return authRepository.isUserLoggedIn()
    }

    // Função para fazer o Login
    fun login(email: String, pass: String, onSuccess: () -> Unit, onError: (String) -> Unit) {
        viewModelScope.launch {
            val result = authRepository.loginWithEmail(email, pass)
            result.onSuccess {
                onSuccess()
            }.onFailure {
                onError(it.message ?: "Erro ao fazer login")
            }
        }
    }

    // Função para criar uma Nova Conta
    fun register(email: String, pass: String, onSuccess: () -> Unit, onError: (String) -> Unit) {
        viewModelScope.launch {
            val result = authRepository.registerWithEmail(email, pass)
            result.onSuccess {
                onSuccess()
            }.onFailure {
                onError(it.message ?: "Erro ao criar conta")
            }
        }
    }

    fun logout() {
        authRepository.logout()
    }
}