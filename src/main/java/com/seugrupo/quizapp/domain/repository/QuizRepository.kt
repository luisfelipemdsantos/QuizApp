package com.seugrupo.quizapp.domain.repository

import com.seugrupo.quizapp.domain.model.Question
import com.seugrupo.quizapp.domain.model.QuizResult
import com.seugrupo.quizapp.domain.model.RankingEntry // IMPORTADO

interface QuizRepository {
    suspend fun syncQuestionsFromFirebase(): Result<Unit>
    suspend fun getLocalQuestions(): List<Question>
    suspend fun saveQuizResult(result: QuizResult): Result<Unit>
    suspend fun getUserHistory(userId: String): List<QuizResult>
    suspend fun getGlobalRanking(): List<RankingEntry> // NOVO MÉTODO
}