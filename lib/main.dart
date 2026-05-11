import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart'; 
import 'package:jaydi_delivery/screens/main_menu.dart'; 
import 'package:jaydi_delivery/screens/login_screen.dart';
import 'package:jaydi_delivery/screens/registro_screen.dart';
import 'package:jaydi_delivery/services/api_delivery_service.dart'; 

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  bool isLoggedIn = false;
  String initialRoute = '/login'; 

  try {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

    if (isLoggedIn) {
      final apiService = ApiDeliveryService();
      // Asegúrate de que el método en api_delivery_service.dart se llame getPerfil
      final userData = await apiService.getPerfil(); 

      if (userData != null) {
        String status = userData['status'] ?? 'pendiente';
        await prefs.setString('userStatus', status);
        initialRoute = '/home'; 
      } else {
        // Si hay sesión pero no carga el perfil, igual mandamos al home o re-login
        initialRoute = '/home'; 
      }
    }
  } catch (e) {
    debugPrint("Error al sincronizar con la nube: $e");
  }

  // CORRECCIÓN: Ahora pasamos ambos parámetros correctamente
  runApp(JaydiDeliveryApp(
    isLoggedIn: isLoggedIn, 
    initialRoute: initialRoute
  ));
}

class JaydiDeliveryApp extends StatelessWidget {
  final bool isLoggedIn;
  final String initialRoute; // AGREGADO: Para recibir la ruta calculada
  
  const JaydiDeliveryApp({
    super.key, 
    required this.isLoggedIn, 
    required this.initialRoute // AGREGADO al constructor
  });

  @override
  Widget build(BuildContext context) {
    const Color jaydiOrange = Color(0xFFFF5722);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Jaydi Delivery',
      theme: ThemeData(
        useMaterial3: true,
        primaryColor: jaydiOrange,
        textTheme: GoogleFonts.montserratTextTheme(Theme.of(context).textTheme),
        colorScheme: ColorScheme.fromSeed(
          seedColor: jaydiOrange,
          primary: jaydiOrange,
          secondary: Colors.orangeAccent,
          surface: Colors.white,
          brightness: Brightness.light,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: jaydiOrange,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
      // CORRECCIÓN: Usamos initialRoute que viene del main()
      initialRoute: initialRoute, 
      routes: {
        '/login': (context) => const LoginScreen(),
        '/registro': (context) => const RegistroScreen(),
        '/home': (context) => const MainMenu(),
      },
      onUnknownRoute: (settings) => MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }
}