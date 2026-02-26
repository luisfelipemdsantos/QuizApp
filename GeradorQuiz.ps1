$basePkg = "app\src\main\java\com\seugrupo\quizapp"

Write-Host "A iniciar a criacao da arquitetura do Quiz App..." -ForegroundColor Cyan

function Write-CodeFile {
    param ([string]$Path, [string]$Content)
    $fullPath = Join-Path (Get-Location) $Path
    $dir = Split-Path $fullPath
    if (!(Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    [IO.File]::WriteAllText($fullPath, $Content.Trim(), [System.Text.Encoding]::UTF8)
    Write-Host "Criado: $Path" -ForegroundColor Green
}

# 1. DOMAIN LAYER
$models = @"
package com.seugrupo.quizapp.domain.model
data class Question(val id: String = "", val text: String = "", val options: List<String> = emptyList(), val correctOptionIndex: Int = 0)
data class QuizResult(val id: String = "", val userId: String = "", val score: Int = 0, val totalQuestions: Int = 0, val date: Long = System.currentTimeMillis())
"@
Write-CodeFile "$basePkg\domain\model\Models.kt" $models

$authRepoInt = @"
package com.seugrupo.quizapp.domain.repository
interface AuthRepository {
    fun isUserLoggedIn(): Boolean
    fun getCurrentUserId(): String?
    suspend fun loginWithEmail(email: String, pass: String): Result<Unit>
    suspend fun registerWithEmail(email: String, pass: String): Result<Unit>
    fun logout()
}
"@
Write-CodeFile "$basePkg\domain\repository\AuthRepository.kt" $authRepoInt

$quizRepoInt = @"
package com.seugrupo.quizapp.domain.repository
import com.seugrupo.quizapp.domain.model.Question
import com.seugrupo.quizapp.domain.model.QuizResult
interface QuizRepository {
    suspend fun syncQuestionsFromFirebase(): Result<Unit>
    suspend fun getLocalQuestions(): List<Question>
    suspend fun saveQuizResult(result: QuizResult): Result<Unit>
    suspend fun getUserHistory(userId: String): List<QuizResult>
}
"@
Write-CodeFile "$basePkg\domain\repository\QuizRepository.kt" $quizRepoInt

# 2. DATA LAYER (LOCAL & REMOTE)
$entities = @"
package com.seugrupo.quizapp.data.local
import androidx.room.Entity
import androidx.room.PrimaryKey
@Entity(tableName = "questions")
data class QuestionEntity(@PrimaryKey val id: String, val text: String, val options: String, val correctIndex: Int)
@Entity(tableName = "quiz_history")
data class HistoryEntity(@PrimaryKey(autoGenerate = true) val id: Int = 0, val userId: String, val score: Int, val totalQuestions: Int, val date: Long)
"@
Write-CodeFile "$basePkg\data\local\Entities.kt" $entities

$converters = @"
package com.seugrupo.quizapp.data.local
import androidx.room.TypeConverter
import com.google.gson.Gson
import com.google.gson.reflect.TypeToken
class Converters {
    @TypeConverter fun fromStringList(value: List<String>): String = Gson().toJson(value)
    @TypeConverter fun toStringList(value: String): List<String> = Gson().fromJson(value, object : TypeToken<List<String>>() {}.type)
}
"@
Write-CodeFile "$basePkg\data\local\Converters.kt" $converters

$quizDao = @"
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
"@
Write-CodeFile "$basePkg\data\local\QuizDao.kt" $quizDao

$appDatabase = @"
package com.seugrupo.quizapp.data.local
import android.content.Context
import androidx.room.Database
import androidx.room.Room
import androidx.room.RoomDatabase
import androidx.room.TypeConverters
@Database(entities = [QuestionEntity::class, HistoryEntity::class], version = 1, exportSchema = false)
@TypeConverters(Converters::class)
abstract class AppDatabase : RoomDatabase() {
    abstract fun quizDao(): QuizDao
    companion object {
        @Volatile private var INSTANCE: AppDatabase? = null
        fun getDatabase(context: Context): AppDatabase = INSTANCE ?: synchronized(this) {
            Room.databaseBuilder(context.applicationContext, AppDatabase::class.java, "quiz_database").build().also { INSTANCE = it }
        }
    }
}
"@
Write-CodeFile "$basePkg\data\local\AppDatabase.kt" $appDatabase

$authRepoImpl = @"
package com.seugrupo.quizapp.data.repository
import com.google.firebase.auth.FirebaseAuth
import com.seugrupo.quizapp.domain.repository.AuthRepository
import kotlinx.coroutines.tasks.await
class AuthRepositoryImpl(private val auth: FirebaseAuth) : AuthRepository {
    override fun isUserLoggedIn(): Boolean = auth.currentUser != null
    override fun getCurrentUserId(): String? = auth.currentUser?.uid
    override suspend fun loginWithEmail(email: String, pass: String): Result<Unit> = try { auth.signInWithEmailAndPassword(email, pass).await(); Result.success(Unit) } catch (e: Exception) { Result.failure(e) }
    override suspend fun registerWithEmail(email: String, pass: String): Result<Unit> = try { auth.createUserWithEmailAndPassword(email, pass).await(); Result.success(Unit) } catch (e: Exception) { Result.failure(e) }
    override fun logout() { auth.signOut() }
}
"@
Write-CodeFile "$basePkg\data\repository\AuthRepositoryImpl.kt" $authRepoImpl

$quizRepoImpl = @"
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
        Result.success(Unit)
    } catch (e: Exception) { Result.failure(e) }
    override suspend fun getUserHistory(userId: String): List<QuizResult> = dao.getUserHistory(userId).map { QuizResult(it.id.toString(), it.userId, it.score, it.totalQuestions, it.date) }
}
"@
Write-CodeFile "$basePkg\data\repository\QuizRepositoryImpl.kt" $quizRepoImpl

# 3. PRESENTATION LAYER
$authVm = @"
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
"@
Write-CodeFile "$basePkg\presentation\auth\AuthViewModel.kt" $authVm

$loginScreen = @"
package com.seugrupo.quizapp.presentation.auth
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
@Composable fun LoginScreen(viewModel: AuthViewModel, onNavigateToHome: () -> Unit) {
    val authState by viewModel.state.collectAsState()
    var email by remember { mutableStateOf("") }
    var password by remember { mutableStateOf("") }
    LaunchedEffect(authState) { if (authState is AuthState.Authenticated) onNavigateToHome() }
    Column(modifier = Modifier.fillMaxSize().padding(24.dp), verticalArrangement = Arrangement.Center, horizontalAlignment = Alignment.CenterHorizontally) {
        Text("Quiz App", style = MaterialTheme.typography.headlineLarge)
        Spacer(Modifier.height(32.dp))
        OutlinedTextField(value = email, onValueChange = { email = it }, label = { Text("E-mail") }, modifier = Modifier.fillMaxWidth())
        Spacer(Modifier.height(16.dp))
        OutlinedTextField(value = password, onValueChange = { password = it }, label = { Text("Senha") }, visualTransformation = PasswordVisualTransformation(), modifier = Modifier.fillMaxWidth())
        Spacer(Modifier.height(24.dp))
        if (authState is AuthState.Loading) CircularProgressIndicator() else Button(onClick = { viewModel.login(email, password) }, modifier = Modifier.fillMaxWidth()) { Text("Entrar") }
        if (authState is AuthState.Error) Text((authState as AuthState.Error).message, color = MaterialTheme.colorScheme.error, modifier = Modifier.padding(top=16.dp))
    }
}
"@
Write-CodeFile "$basePkg\presentation\auth\LoginScreen.kt" $loginScreen

$homeScreen = @"
package com.seugrupo.quizapp.presentation.home
import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ExitToApp
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
@OptIn(ExperimentalMaterial3Api::class)
@Composable fun HomeScreen(onStartQuiz: () -> Unit, onViewHistory: () -> Unit, onLogout: () -> Unit) {
    Scaffold(topBar = { TopAppBar(title = { Text("Dashboard") }, actions = { IconButton(onClick = onLogout) { Icon(Icons.Default.ExitToApp, "Sair") } }) }) { paddingValues ->
        Column(modifier = Modifier.fillMaxSize().padding(paddingValues).padding(24.dp), verticalArrangement = Arrangement.Center, horizontalAlignment = Alignment.CenterHorizontally) {
            Card(modifier = Modifier.fillMaxWidth(), elevation = CardDefaults.cardElevation(defaultElevation = 4.dp)) {
                Column(modifier = Modifier.padding(24.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                    Text("Bem-vindo!", style = MaterialTheme.typography.titleLarge)
                    Spacer(Modifier.height(24.dp))
                    Button(onClick = onStartQuiz, modifier = Modifier.fillMaxWidth()) { Text("Iniciar Novo Quiz") }
                    Spacer(Modifier.height(16.dp))
                    OutlinedButton(onClick = onViewHistory, modifier = Modifier.fillMaxWidth()) { Text("Ver Meu Histórico") }
                }
            }
        }
    }
}
"@
Write-CodeFile "$basePkg\presentation\home\HomeScreen.kt" $homeScreen

$quizVm = @"
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
"@
Write-CodeFile "$basePkg\presentation\quiz\QuizViewModel.kt" $quizVm

$quizScreen = @"
package com.seugrupo.quizapp.presentation.quiz
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
@OptIn(ExperimentalMaterial3Api::class)
@Composable fun QuizScreen(viewModel: QuizViewModel, onQuizFinished: () -> Unit) {
    val state by viewModel.state.collectAsState()
    LaunchedEffect(Unit) { viewModel.loadQuestions() }
    Scaffold(topBar = { TopAppBar(title = { Text("A Jogar") }) }) { padding ->
        Box(modifier = Modifier.padding(padding).fillMaxSize(), contentAlignment = Alignment.Center) {
            when (val currentState = state) {
                is QuizState.Loading -> CircularProgressIndicator()
                is QuizState.Error -> Text("Erro: `"$`{currentState.message}")
                is QuizState.Finished -> Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text("Fim do Quiz!", style = MaterialTheme.typography.headlineMedium)
                    Text("Pontuação: `"$`{currentState.score} de `"$`{currentState.total}", style = MaterialTheme.typography.titleLarge, modifier = Modifier.padding(vertical = 8.dp))
                    Button(onClick = onQuizFinished) { Text("Voltar") }
                }
                is QuizState.Active -> Column(modifier = Modifier.padding(24.dp).fillMaxSize(), horizontalAlignment = Alignment.CenterHorizontally) {
                    val question = currentState.questions[currentState.currentIndex]
                    Text("Pergunta `"$`{currentState.currentIndex + 1} de `"$`{currentState.questions.size}")
                    Text(question.text, style = MaterialTheme.typography.headlineSmall, modifier = Modifier.padding(vertical = 16.dp))
                    question.options.forEachIndexed { index, option -> OutlinedButton(onClick = { viewModel.submitAnswer(index) }, modifier = Modifier.fillMaxWidth().padding(vertical = 4.dp)) { Text(option) } }
                }
            }
        }
    }
}
"@
Write-CodeFile "$basePkg\presentation\quiz\QuizScreen.kt" $quizScreen

$historyVm = @"
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
"@
Write-CodeFile "$basePkg\presentation\history\HistoryViewModel.kt" $historyVm

$historyScreen = @"
package com.seugrupo.quizapp.presentation.history
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
@OptIn(ExperimentalMaterial3Api::class)
@Composable fun HistoryScreen(viewModel: HistoryViewModel, onBack: () -> Unit) {
    val history by viewModel.history.collectAsState()
    Scaffold(topBar = { TopAppBar(title = { Text("Histórico") }, navigationIcon = { IconButton(onClick = onBack) { Icon(Icons.Default.ArrowBack, "Voltar") } }) }) { padding ->
        if (history.isEmpty()) Text("Nenhum quiz.", modifier = Modifier.padding(padding).padding(16.dp))
        else LazyColumn(modifier = Modifier.padding(padding).padding(16.dp)) {
            items(history) { result -> Card(modifier = Modifier.fillMaxWidth().padding(vertical = 4.dp)) { Column(modifier = Modifier.padding(16.dp)) { Text("Data: `"$`{viewModel.formatDate(result.date)}") ; Text("Score: `"$`{result.score}/${result.totalQuestions}") } } }
        }
    }
}
"@
Write-CodeFile "$basePkg\presentation\history\HistoryScreen.kt" $historyScreen

$appFactory = @"
package com.seugrupo.quizapp.presentation
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import com.seugrupo.quizapp.domain.repository.*
import com.seugrupo.quizapp.presentation.auth.AuthViewModel
import com.seugrupo.quizapp.presentation.history.HistoryViewModel
import com.seugrupo.quizapp.presentation.quiz.QuizViewModel
class AppViewModelFactory(private val authRepository: AuthRepository, private val quizRepository: QuizRepository) : ViewModelProvider.Factory {
    override fun <T : ViewModel> create(modelClass: Class<T>): T {
        if (modelClass.isAssignableFrom(AuthViewModel::class.java)) return AuthViewModel(authRepository) as T
        if (modelClass.isAssignableFrom(QuizViewModel::class.java)) return QuizViewModel(quizRepository, authRepository) as T
        if (modelClass.isAssignableFrom(HistoryViewModel::class.java)) return HistoryViewModel(quizRepository, authRepository) as T
        throw IllegalArgumentException("Classe desconhecida")
    }
}
"@
Write-CodeFile "$basePkg\presentation\AppViewModelFactory.kt" $appFactory

$appNav = @"
package com.seugrupo.quizapp.presentation
import androidx.compose.runtime.*
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.compose.*
import com.seugrupo.quizapp.presentation.auth.*
import com.seugrupo.quizapp.presentation.home.*
import com.seugrupo.quizapp.presentation.quiz.*
import com.seugrupo.quizapp.presentation.history.*
@Composable fun AppNavigation(viewModelFactory: AppViewModelFactory) {
    val navController = rememberNavController()
    val authViewModel: AuthViewModel = viewModel(factory = viewModelFactory)
    val authState by authViewModel.state.collectAsState()
    NavHost(navController = navController, startDestination = if (authState is AuthState.Authenticated) "home" else "login") {
        composable("login") { LoginScreen(viewModel = authViewModel) { navController.navigate("home") { popUpTo("login") { inclusive = true } } } }
        composable("home") { HomeScreen(onStartQuiz = { navController.navigate("quiz") }, onViewHistory = { navController.navigate("history") }, onLogout = { navController.navigate("login") { popUpTo("home") { inclusive = true } } }) }
        composable("quiz") { QuizScreen(viewModel = viewModel(factory = viewModelFactory)) { navController.popBackStack() } }
        composable("history") { HistoryScreen(viewModel = viewModel(factory = viewModelFactory)) { navController.popBackStack() } }
    }
}
"@
Write-CodeFile "$basePkg\presentation\AppNavigation.kt" $appNav

$mainActivity = @"
package com.seugrupo.quizapp
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FirebaseFirestore
import com.seugrupo.quizapp.data.local.AppDatabase
import com.seugrupo.quizapp.data.repository.*
import com.seugrupo.quizapp.presentation.*
class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val database = AppDatabase.getDatabase(this)
        val auth = FirebaseAuth.getInstance()
        val firestore = FirebaseFirestore.getInstance()
        
        // DESCOMENTE A LINHA ABAIXO PARA POPULAR O BANCO NA PRIMEIRA VEZ:
        // com.seugrupo.quizapp.utils.FirebaseSeeder.popularBancoDeDados(firestore)

        setContent { MaterialTheme { Surface { AppNavigation(AppViewModelFactory(AuthRepositoryImpl(auth), QuizRepositoryImpl(database.quizDao(), firestore))) } } }
    }
}
"@
Write-CodeFile "$basePkg\MainActivity.kt" $mainActivity

$seeder = @"
package com.seugrupo.quizapp.utils
import com.google.firebase.firestore.FirebaseFirestore
object FirebaseSeeder {
    fun popularBancoDeDados(firestore: FirebaseFirestore) {
        val collection = firestore.collection("questions")
        val perguntas = listOf(
            mapOf("text" to "Qual componente do Compose cria listas eficientes?", "options" to listOf("Column", "ScrollView", "LazyColumn", "ListView"), "correctIndex" to 2),
            mapOf("text" to "No Room, qual anotação define uma tabela?", "options" to listOf("@Table", "@Entity", "@Database", "@RoomTable"), "correctIndex" to 1)
        )
        perguntas.forEach { collection.add(it) }
    }
}
"@
Write-CodeFile "$basePkg\utils\FirebaseSeeder.kt" $seeder
Write-Host "Processo concluido com sucesso!" -ForegroundColor Yellow
