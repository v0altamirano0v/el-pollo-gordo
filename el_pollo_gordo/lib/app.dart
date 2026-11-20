import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme.dart';
import 'state/app_state.dart';
import 'ui/home_screen.dart';
import 'ui/role_select_screen.dart';

class PolloGordoApp extends StatelessWidget {
  const PolloGordoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState()..init(),
      child: MaterialApp(
        title: 'El Pollo Gordo - Gestión de Ventas',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: const AppRouter(),
      ),
    );
  }
}

class AppRouter extends StatelessWidget {
  const AppRouter({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    if (!state.listo) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (!state.dbDisponible) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              state.error ?? 'No se pudo iniciar la base de datos.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ),
      );
    }
    if (state.empleado == null || state.establecimiento == null) {
      return const RoleSelectScreen();
    }
    return const HomeScreen();
  }
}
