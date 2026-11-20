import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/db_client.dart';
import '../core/format.dart';
import '../models/entities.dart';
import '../state/app_state.dart';
import 'widgets.dart';

class DeliveryAsignacionScreen extends StatefulWidget {
  const DeliveryAsignacionScreen({super.key});

  @override
  State<DeliveryAsignacionScreen> createState() => _DeliveryAsignacionScreenState();
}

class _DeliveryAsignacionScreenState extends State<DeliveryAsignacionScreen> {
  List<DbRow> _entregas = [];
  final Map<int, DbRow> _pedidos = {};
  final Map<int, int?> _seleccion = {};
  bool _cargando = true;

  Future<void> _cargar() async {
    final state = context.read<AppState>();
    if (!state.listo) return;
    final entregas = await state.repo.entregas();
    final pedidos = await state.repo.pedidos(tipo: 'delivery');
    final map = <int, DbRow>{};
    for (final p in pedidos) {
      map[p.intOf('id')] = p;
      final entrega = entregas.where((e) => e.intOf('pedido_id') == p.intOf('id'));
      if (entrega.isNotEmpty) {
        _seleccion[entrega.first.intOf('id')] = entrega.first.intOpt('repartidor_id');
      }
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

  String _nombreRepartidor(AppState state, int? id) {
    if (id == null) return 'Sin asignar';
    final rows = state.empleados.where((e) => e.intOf('id') == id);
    return rows.isEmpty ? 'Repartidor $id' : rows.first.str('nombre');
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.small(onPressed: _cargar, child: const Icon(Icons.refresh)),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _entregas.isEmpty
              ? const EmptyView('No hay entregas registradas', icon: Icons.local_shipping_outlined)
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _entregas.length,
                  itemBuilder: (context, index) {
                    final e = _entregas[index];
                    final pedido = _pedidos[e.intOf('pedido_id')];
                    final estado = e.str('estado');
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Expanded(child: Text('Pedido ${pedido?.str('numero') ?? e.intOf('pedido_id')}',
                                    style: const TextStyle(fontWeight: FontWeight.bold))),
                                StatusChip(estado),
                              ],
                            ),
                            InfoLine('Cliente', e.str('telefono').isEmpty ? e.str('direccion') : '${e.str('telefono')} · ${e.str('direccion')}'),
                            InfoLine('Referencia', e.str('referencia').isEmpty ? '-' : e.str('referencia')),
                            InfoLine('Total + envío', AppFormat.currency(pedido?.doubleOf('total') ?? 0)),
                            InfoLine('Repartidor', _nombreRepartidor(state, e.intOpt('repartidor_id'))),
                            InfoLine('Intentos de contacto', '${e.intOf('intentos_contacto')}'),
                            if (e.intOf('es_duplicado_sospechoso') == 1)
                              const Text('Posible duplicado: validado por caja', style: TextStyle(color: Colors.orange)),
                            if (e.str('incidencia').isNotEmpty)
                              Text('Incidencia: ${e.str('incidencia')}', style: const TextStyle(color: Colors.orange)),
                            const SizedBox(height: 10),
                            DropdownButtonFormField<int>(
                              value: _seleccion[e.intOf('id')],
                              decoration: const InputDecoration(labelText: 'Repartidor'),
                              items: state.repartidores.map((r) => DropdownMenuItem<int>(
                                    value: r.intOf('id'),
                                    child: Text(r.str('nombre')),
                                  )).toList(),
                              onChanged: (v) => setState(() => _seleccion[e.intOf('id')] = v),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                FilledButton.icon(
                                  onPressed: _seleccion[e.intOf('id')] == null
                                      ? null
                                      : () async {
                                          final id = _seleccion[e.intOf('id')];
                                          if (estado == 'pendiente') {
                                            await state.run(() => state.repo.asignarRepartidor(
                                                  e.intOf('id'), id!, cajeroId: state.empleadoId));
                                          } else {
                                            await state.run(() => state.repo.reasignarRepartidor(
                                                  e.intOf('id'), id!, 'Reasignado desde caja'));
                                          }
                                          await _cargar();
                                          if (context.mounted) showMessage(context, 'Repartidor actualizado');
                                        },
                                  icon: const Icon(Icons.two_wheeler),
                                  label: Text(estado == 'pendiente' ? 'Asignar' : 'Reasignar'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () async {
                                    await state.run(() => state.repo.registrarIntentoContacto(e.intOf('id')));
                                    await _cargar();
                                    if (context.mounted) showMessage(context, 'Intento de contacto registrado');
                                  },
                                  icon: const Icon(Icons.phone_callback),
                                  label: const Text('Registrar llamada'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () => _registrarIncidencia(context, e.intOf('id')),
                                  icon: const Icon(Icons.report_problem_outlined),
                                  label: const Text('Incidencia'),
                                ),
                                if (estado != 'entregado' && estado != 'devuelto')
                                  OutlinedButton.icon(
                                    onPressed: () async {
                                      final ok = await confirmAction(context, 'Devolver pedido',
                                          '¿Registrar devolución del pedido ${pedido?.str('numero') ?? ''}?');
                                      if (!ok) return;
                                      await state.run(() => state.repo.registrarEntregaFallida(
                                            entregaId: e.intOf('id'),
                                            motivo: 'Devolución gestionada desde caja',
                                            accion: 'devolver',
                                          ));
                                      await _cargar();
                                      if (context.mounted) showMessage(context, 'Devolución registrada');
                                    },
                                    icon: const Icon(Icons.undo),
                                    label: const Text('Devolver'),
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

  Future<void> _registrarIncidencia(BuildContext context, int entregaId) async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Registrar incidencia de entrega'),
        content: TextField(controller: controller, decoration: const InputDecoration(labelText: 'Detalle'), maxLines: 3),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Guardar')),
        ],
      ),
    );
    if (ok != true || controller.text.trim().isEmpty) return;
    final state = context.read<AppState>();
    final entregas = await state.repo.db.query('entrega_delivery', where: {'id': entregaId});
    final pedidoId = entregas.isEmpty ? 0 : entregas.first.intOf('pedido_id');
    await state.run(() async {
      if (pedidoId != 0) {
        await state.repo.reportarIncidencia(pedidoId, controller.text.trim());
      }
    });
    await _cargar();
    if (context.mounted) showMessage(context, 'Incidencia registrada');
  }
}
