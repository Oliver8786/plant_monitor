import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login.dart';
import 'widgets/moisture_chart.dart';
import 'pages/plant_monitor_page.dart';

class PlantMonitorApp extends StatelessWidget {
  const PlantMonitorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Plant Monitor',
      theme: ThemeData(
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.grey.shade300,
          brightness: Brightness.light,
          primary: Colors.grey.shade900,
          onPrimary: Colors.white,
          background: Colors.white,
          surface: Colors.white,
          onSurface: Colors.grey.shade900,
        ),
        scaffoldBackgroundColor: Colors.white,
        cardColor: Colors.white,
        textTheme: const TextTheme(
          titleMedium: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
            fontSize: 18,
            letterSpacing: 0.15,
          ),
          bodyMedium: TextStyle(
            color: Colors.black54,
            fontSize: 14,
            letterSpacing: 0.25,
          ),
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.grey.shade800,
          brightness: Brightness.dark,
          primary: Colors.grey.shade100,
          onPrimary: Colors.black,
          background: Colors.grey.shade900,
          surface: Colors.grey.shade800,
          onSurface: Colors.grey.shade100,
        ),
        scaffoldBackgroundColor: Colors.grey.shade900,
        cardColor: Colors.grey.shade800,
        textTheme: const TextTheme(
          titleMedium: TextStyle(
            color: Colors.white70,
            fontWeight: FontWeight.w600,
            fontSize: 18,
            letterSpacing: 0.15,
          ),
          bodyMedium: TextStyle(
            color: Colors.white60,
            fontSize: 14,
            letterSpacing: 0.25,
          ),
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      home: const AuthGate(),
    );
  }
}


/// Shows appropriate page depending on FirebaseAuth state.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          // Show loading indicator while checking auth state
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasData && snapshot.data != null) {
          // User is signed in
          return PlantMonitorPage();
        } else {
          // User is NOT signed in
          return LoginPage();
        }
      },
    );
  }
}