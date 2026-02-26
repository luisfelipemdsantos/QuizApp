package com.seugrupo.quizapp.data.repository
import com.google.firebase.firestore.FirebaseFirestore
import com.google.gson.Gson
import com.google.gson.reflect.TypeToken
import com.seugrupo.quizapp.data.local.*
import com.seugrupo.quizapp.domain.model.*
import com.seugrupo.quizapp.domain.repository.QuizRepository
import kotlinx.coroutines.tasks.await
class QuizRepositoryImpl(private val dao: QuizDao, private val firestore: FirebaseFirestore) : QuizRepository {
    private val gson = Gson()
    override suspend fun syncQuestionsFromFirebase(): Result<Unit> = try {
        val snapshot = firestore.collection("questions").get().await()
        val questionsDb = snapshot.documents.mapNotNull { doc ->
            val optionsStringList = (doc.get("options") as? List<*>)?.map { it.toString() } ?: emptyList()
            QuestionEntity(doc.id, doc.getString("text") ?: "", gson.toJson(optionsStringList), doc.getLong("correctIndex")?.toInt() ?: 0)
        }
        if (questionsDb.isNotEmpty()) dao.insertQuestions(questionsDb)
        Result.success(Unit)
    } catch (e: Exception) { Result.failure(e) }
    override suspend fun getLocalQuestions(): List<Question> = dao.getAllQuestions().map { entity -> Question(entity.id, entity.text, gson.fromJson(entity.options, object : TypeToken<List<String>>() {}.type), entity.correctIndex) }
    override suspend fun saveQuizResult(result: QuizResult): Result<Unit> = try {
        dao.insertHistory(HistoryEntity(userId = result.userId, score = result.score, totalQuestions = result.totalQuestions, date = result.date))
        firestore.collection("users").document(result.userId).collection("history").add(hashMapOf("userId" to result.userId, "score" to result.score, "totalQuestions" to result.totalQuestions, "date" to result.date)).await()

        // LÓGICA PARA ATUALIZAR O RANKING GLOBAL
        val userDoc = firestore.collection("users").document(result.userId).get().await()
        val email = userDoc.getString("email") ?: "Anônimo"
        val rankingRef = firestore.collection("ranking").document(result.userId)
        val currentRanking = rankingRef.get().await()
        val bestScore = currentRanking.getLong("score") ?: 0

        if (result.score > bestScore) { // Atualiza apenas se a nova pontuação for maior
            rankingRef.set(hashMapOf("userId" to result.userId, "userEmail" to email, "score" to result.score, "date" to result.date)).await()
        }

        Result.success(Unit)
    } catch (e: Exception) { Result.failure(e) }

    override suspend fun getUserHistory(userId: String): List<QuizResult> = dao.getUserHistory(userId).map { QuizResult(it.id.toString(), it.userId, it.score, it.totalQuestions, it.date) }

    // IMPLEMENTAÇÃO DO RANKING GLOBAL
    override suspend fun getGlobalRanking(): List<RankingEntry> = try {
        val snapshot = firestore.collection("ranking").orderBy("score", com.google.firebase.firestore.Query.Direction.DESCENDING).limit(10).get().await()
        snapshot.documents.map { doc ->
            RankingEntry(doc.getString("userId") ?: "", doc.getString("userEmail") ?: "", doc.getLong("score")?.toInt() ?: 0, doc.getLong("date") ?: 0)
        }
    } catch (e: Exception) { emptyList() }
}