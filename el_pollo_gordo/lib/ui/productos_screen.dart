import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/format.dart';
import '../models/entities.dart';
import '../state/app_state.dart';
import 'widgets.dart';

class ProductosScreen extends StatelessWidget {
  const ProductosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: SectionCard(
        title: 'Catálogo y equivalencia de consumo de pollo',
        child: ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: state.productos.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final p = state.productos[index];
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: p.str('tipo') == 'pollo' ? Colors.orange.shade100 : Colors.green.shade100,
                child: Icon(p.str('tipo') == 'pollo' ? Icons.restaurant : Icons.fastfood),
              ),
              title: Text(p.str('nombre')),
              subtitle: Text('Código ${p.str('codigo')} · ${p.str('tipo')}'),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(AppFormat.currency(p.doubleOf('precio')), style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text('${p.doubleOf('equivalencia_pollo').toStringAsFixed(3)} pollo',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
