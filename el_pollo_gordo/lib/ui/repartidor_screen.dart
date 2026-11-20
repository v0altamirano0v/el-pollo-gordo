import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/db_client.dart';
import '../core/format.dart';
import '../models/entities.dart';
import '../state/app_state.dart';
import 'widgets.dart';

class RepartidorScreen extends StatefulWidget {
  const RepartidorScreen({super.key});

  @override
  State<RepartidorScreen> createState() => _RepartidorScreenState();
}

class _RepartidorScreenState extends State<RepartidorScreen> {
  List<DbRow> _entregas = [];
  final Map<int, DbRow> _pedidos = {};
  bool _cargando = true;

  Future<void> _cargar() async {
    final state = context.read<AppState>();
    if (!state.listo || state.empleadoId == null) return;
    final entregas = await state.repo.entregas(repartidorId: state.empleadoId);
    final pedidos = await state.repo.pedidos(tipo: 'delivery');
    final map = <int, DbRow>{};
    for (final p in pedidos) {
      map[p.intOf('id')] = p;
    }
    if (!mounted) return;
    setState(() {
      _entregas = entregas;
      _pedidos.clear();
      _pedidos.addAll(map);
      _cargando = false;
    });
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(_cargar);
  }

  Future<void> _entregar(BuildContext context, DbRow entrega, double esperado) async {
    final controller = TextEditingController(text: esperado.toStringAsFixed(2));
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Registrar entrega y cobro'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Monto esperado: ${AppFormat.currency(esperado)}'),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Efectivo cobrado'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirmar entrega')),
        ],
      ),
    );
    if (ok != true) return;
    final cobrado = double.tryParse(controller.text.replaceAll(',', '.')) ?? 0;
    final state = context.read<AppState>();
    await state.run(() => state.repo.registrarEntregaDelivery(
          entregaId: entrega.intOf('id'),
          cobrado: cobrado,
          observacion: 'Entrega registrada por repartidor',
        ));
    await _cargar();
    if (context.mounted) showMessage(context, 'Entrega registrada. Render el efectivo en Caja');
  }

  Future<void> _fallida(BuildContext context, DbRow entrega) async {
    final motivo = TextEditingController();
    String accion = 'reintentar';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Entrega fallida'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: motivo, decoration: const InputDecoration(labelText: 'Motivo / incidencia'), maxLines: 3),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: accion,
                decoration: const InputDecoration(labelText: 'Acción'),
                items: const [
                  DropdownMenuItem(value: 'reintentar', child: Text('Mantener para reintento')),
                  DropdownMenuItem(value: 'devolver', child: Text('Devolver a local')),
                ],
                onChanged: (v) => setLocal(() => accion = v ?? 'reintentar'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Guardar')),
          ],
        ),
      ),
    );
    if (ok != true || motivo.text.trim().isEmpty) return;
    final state = context.read<AppState>();
    await state.run(() => state.repo.registrarEntregaFallida(
          entregaId: entrega.intOf('id'),
          motivo: motivo.text.trim(),
          accion: accion,
        ));
    await _cargar();
    if (context.mounted) showMessage(context, 'Incidencia de entrega registrada');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.small(onPressed: _cargar, child: const Icon(Icons.refresh)),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _entregas.isEmpty
              ? const EmptyView('No tienes entregas asignadas', icon: Icons.two_wheeler)
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _entregas.length,
                  itemBuilder: (context, index) {
                    final e = _entregas[index];
                    final pedido = _pedidos[e.intOf('pedido_id')];
                    final esperado = pedido?.doubleOf('total') ?? 0;
                    final estado = e.str('estado');
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Expanded(child: Text('Pedido ${pedido?.str('numero') ?? ''}', style: const TextStyle(fontWeight: FontWeight.bold))),
                                StatusChip(estado),
                              ],
                            ),
                            InfoLine('Cliente', e.str('telefono')),
                            InfoLine('Dirección', e.str('direccion')),
                            InfoLine('Referencia', e.str('referencia').isEmpty ? '-' : e.str('referencia')),
                            InfoLine('Cobro esperado', AppFormat.currency(esperado)),
                            InfoLine('Intentos de contacto', '${e.intOf('intentos_contacto')}'),
                            if (e.str('incidencia').isNotEmpty)
                              Text('Incidencia: ${e.str('incidencia')}', style: const TextStyle(color: Colors.orange)),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                if (estado == 'asignado')
                                  FilledButton.icon(
                                    onPressed: () async {
                                      final state = context.read<AppState>();
                                      await state.run(() => state.repo.marcarSalida(e.intOf('id')));
                                      await _cargar();
                                      if (context.mounted) showMessage(context, 'Salida registrada. ¡Buen viaje!');
                                    },
                                    icon: const Icon(Icons.departure_board),
                                    label: const Text('Marcar salida'),
                                  ),
                                OutlinedButton.icon(
                                  onPressed: () async {
                                    final state = context.read<AppState>();
                                    await state.run(() => state.repo.registrarIntentoContacto(e.intOf('id')));
                                    await _cargar();
                                    if (context.mounted) showMessage(context, 'Intento de contacto registrado');
                                  },
                                  icon: const Icon(Icons.phone_callback),
                                  label: const Text('Llamó al cliente'),
                                ),
                                if (estado == 'en_ruta' || estado == 'asignado')
                                  FilledButton.icon(
                                    onPressed: () => _entregar(context, e, esperado),
                                    icon: const Icon(Icons.check_circle),
                                    label: const Text('Entregó y cobró'),
                                  ),
                                if (estado != 'entregado' && estado != 'devuelto')
                                  OutlinedButton.icon(
                                    onPressed: () => _fallida(context, e),
                                    icon: const Icon(Icons.report_problem_outlined),
                                    label: const Text('Entrega fallida'),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
