package com.seugrupo.quizapp.domain.model
data class Question(val id: String = "", val text: String = "", val options: List<String> = emptyList(), val correctOptionIndex: Int = 0)
data class QuizResult(val id: String = "", val userId: String = "", val score: Int = 0, val totalQuestions: Int = 0, val date: Long = System.currentTimeMillis())

data class RankingEntry(val userId: String = "", val userEmail: String = "", val score: Int = 0, val date: Long = System.currentTimeMillis())