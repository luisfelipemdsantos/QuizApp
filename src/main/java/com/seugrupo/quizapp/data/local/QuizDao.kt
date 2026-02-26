package com.seugrupo.quizapp.data.local
import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
@Dao interface QuizDao {
    @Query("SELECT * FROM questions") suspend fun getAllQuestions(): List<QuestionEntity>
    @Insert(onConflict = OnConflictStrategy.REPLACE) suspend fun insertQuestions(questions: List<QuestionEntity>)
    @Insert suspend fun insertHistory(history: HistoryEntity)
    @Query("SELECT * FROM quiz_history WHERE userId = :userId ORDER BY date DESC") suspend fun getUserHistory(userId: String): List<HistoryEntity>
}