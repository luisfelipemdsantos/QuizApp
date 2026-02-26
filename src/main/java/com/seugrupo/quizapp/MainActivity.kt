package com.seugrupo.quizapp

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import com.google.firebase.FirebaseApp // ADICIONE ESTA IMPORTAÇÃO
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FirebaseFirestore
import com.seugrupo.quizapp.data.local.AppDatabase
import com.seugrupo.quizapp.data.repository.AuthRepositoryImpl
import com.seugrupo.quizapp.data.repository.QuizRepositoryImpl
import com.seugrupo.quizapp.presentation.AppNavigation
import com.seugrupo.quizapp.presentation.AppViewModelFactory

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // 1. FORÇA A INICIALIZAÇÃO DO FIREBASE ANTES DE TUDO!
        FirebaseApp.initializeApp(this)

        val database = AppDatabase.getDatabase(this)
        val auth = FirebaseAuth.getInstance()
        val firestore = FirebaseFirestore.getInstance()

        // Passando o firestore também no AuthRepository (conforme nossa última alteração)
        val authRepository = AuthRepositoryImpl(auth, firestore)
        val quizRepository = QuizRepositoryImpl(database.quizDao(), firestore)
        val factory = AppViewModelFactory(authRepository, quizRepository)

        setContent {
            MaterialTheme {
                Surface {
                    AppNavigation(viewModelFactory = factory)
                }
            }
        }
    }
}