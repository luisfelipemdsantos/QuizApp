package com.seugrupo.quizapp.data.local
import androidx.room.Entity
import androidx.room.PrimaryKey
@Entity(tableName = "questions")
data class QuestionEntity(@PrimaryKey val id: String, val text: String, val options: String, val correctIndex: Int)
@Entity(tableName = "quiz_history")
data class HistoryEntity(@PrimaryKey(autoGenerate = true) val id: Int = 0, val userId: String, val score: Int, val totalQuestions: Int, val date: Long)