import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Importante para la sesión
import 'package:jaydi_delivery/screens/main_menu.dart'; 
import 'package:jaydi_delivery/screens/login_screen.dart';
import 'package:jaydi_delivery/screens/registro_screen.dart';

void main() async {
  // 1. Asegura que los servicios de Flutter estén listos
  WidgetsFlutterBinding.ensureInitialized();
  
  // 2. Pregunta a la memoria del teléfono si hay una sesión activa
  SharedPreferences prefs = await SharedPreferences.getInstance();
  bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

  // 3. Arranca la app pasándole el dato de la sesión
  runApp(JaydiDeliveryApp(isLoggedIn: isLoggedIn));
}

class JaydiDeliveryApp extends StatelessWidget {
  final bool isLoggedIn;
  
  const JaydiDeliveryApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Jaydi Delivery',
      theme: ThemeData(
        useMaterial3: true,
        textTheme: GoogleFonts.montserratTextTheme(
          Theme.of(context).textTheme,
        ),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF5722),
          brightness: Brightness.light,
        ),
      ),
      // LA MAGIA: Si isLoggedIn es true, va directo al Home. Si no, al Login.
      initialRoute: isLoggedIn ? '/home' : '/login', 
      routes: {
        '/login': (context) => const LoginScreen(),
        '/registro': (context) => const RegistroScreen(),
        '/home': (context) => const MainMenu(),
      },
    );
  }
}