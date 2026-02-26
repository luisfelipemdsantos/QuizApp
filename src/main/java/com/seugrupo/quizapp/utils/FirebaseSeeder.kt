package com.seugrupo.quizapp.utils

import com.google.firebase.firestore.FirebaseFirestore

object FirebaseSeeder {
    fun popularBancoDeDados(firestore: FirebaseFirestore) {
        val collection = firestore.collection("questions")
        val perguntas = listOf(
            mapOf("text" to "Qual componente do Compose cria listas eficientes?", "options" to listOf("Column", "ScrollView", "LazyColumn", "ListView"), "correctIndex" to 2),
            mapOf("text" to "No Room, qual anotaÃ§Ã£o define uma tabela?", "options" to listOf("@Table", "@Entity", "@Database", "@RoomTable"), "correctIndex" to 1),
            mapOf("text" to "Qual a capital do Brasil?", "options" to listOf("Rio de Janeiro", "São Paulo", "Brasília", "Belo Horizonte"), "correctIndex" to 2),
            mapOf("text" to "Qual o maior oceano do mundo?", "options" to listOf("Atlântico", "Índico", "Ártico", "Pacífico"), "correctIndex" to 3)
        )
        perguntas.forEach { collection.add(it) }
    }
}