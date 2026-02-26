package com.seugrupo.quizapp.domain.repository

interface AuthRepository {
    fun isUserLoggedIn(): Boolean
    fun getCurrentUserId(): String?
    fun getUserEmail(): String? // NOVO MÉTODO
    suspend fun loginWithEmail(email: String, pass: String): Result<Unit>
    suspend fun registerWithEmail(email: String, pass: String): Result<Unit>
    fun logout()
}