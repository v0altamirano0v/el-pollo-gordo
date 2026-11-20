import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants.dart';
import '../core/theme.dart';
import '../models/entities.dart';
import '../state/app_state.dart';
import 'widgets.dart';

class RoleSelectScreen extends StatefulWidget {
  const RoleSelectScreen({super.key});

  @override
  State<RoleSelectScreen> createState() => _RoleSelectScreenState();
}

class _RoleSelectScreenState extends State<RoleSelectScreen> {
  int? _establecimientoId;
  int? _empleadoId;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final ests = state.establecimientos;
    final emps = state.empleados.where((e) {
      if (_establecimientoId == null) return true;
      return e.intOf('establecimiento_id') == _establecimientoId;
    }).toList();

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 980),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppTheme.rojo, AppTheme.rojoClaro],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      children: const [
                        Icon(Icons.restaurant, size: 56, color: AppTheme.mostaza),
                        SizedBox(height: 8),
                        Text(
                          'EL POLLO GORDO',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Gestión de Ventas · Pisco, Perú',
                          style: TextStyle(color: Colors.white70, fontSize: 15),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text('1. Seleccione el establecimiento',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  ResponsiveGrid(
                    children: ests.map((est) {
                      final id = est.intOf('id');
                      final selected = id == _establecimientoId;
                      return Card(
                        color: selected ? AppTheme.crema : null,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => setState(() {
                            _establecimientoId = id;
                            _empleadoId = null;
                          }),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  est.str('tipo') == AppConstants.delivery
                                      ? Icons.two_wheeler
                                      : Icons.storefront,
                                  color: AppTheme.rojo,
                                  size: 30,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  est.str('nombre'),
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  est.str('direccion'),
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                  maxLines: 2,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  Text('2. Seleccione su rol',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  if (_establecimientoId == null)
                    const EmptyView('Primero elija un establecimiento', icon: Icons.storefront_outlined)
                  else
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: emps.map((emp) {
                        final id = emp.intOf('id');
                        final selected = id == _empleadoId;
                        return ChoiceChip(
                          label: Text(
                            '${AppConstants.etiquetaRol(emp.str('rol'))}\n${emp.str('nombre')}',
                            textAlign: TextAlign.center,
                          ),
                          selected: selected,
                          onSelected: (_) => setState(() => _empleadoId = id),
                          selectedColor: AppTheme.crema,
                          side: selected
                              ? const BorderSide(color: AppTheme.rojo, width: 2)
                              : BorderSide(color: Colors.grey.shade300),
                        );
                      }).toList(),
                    ),
                  const SizedBox(height: 28),
                  FilledButton.icon(
                    onPressed: _establecimientoId == null || _empleadoId == null || state.ocupado
                        ? null
                        : () async {
                            await state.selectSession(_establecimientoId!, _empleadoId!);
                            if (context.mounted) showMessage(context, 'Sesión iniciada');
                          },
                    icon: const Icon(Icons.login),
                    label: Text(state.ocupado ? 'Ingresando...' : 'Ingresar al sistema'),
                  ),
                  if (state.error != null) ...[
                    const SizedBox(height: 12),
                    Text(state.error!, style: const TextStyle(color: Colors.red)),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
