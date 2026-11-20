import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants.dart';
import '../core/db_client.dart';
import '../core/format.dart';
import '../models/entities.dart';
import '../state/app_state.dart';
import 'widgets.dart';

class SalonScreen extends StatefulWidget {
  const SalonScreen({super.key});

  @override
  State<SalonScreen> createState() => _SalonScreenState();
}

class _SalonScreenState extends State<SalonScreen> {
  List<PedidoConDetalle> _pedidos = [];
  bool _cargando = true;

  Future<void> _cargar() async {
    final state = context.read<AppState>();
    if (!state.listo) return;
    final lista = await state.repo.pedidosConDetalle(
      establecimientoId: state.establecimientoId,
      tipo: AppConstants.tipoSalon,
      estados: const [
        AppConstants.estadoListo,
        AppConstants.estadoEnRuta,
        AppConstants.estadoEntregado,
      ],
    );
    if (!mounted) return;
    setState(() {
      _pedidos = lista;
      _cargando = false;
    });
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(_cargar);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton:
          FloatingActionButton.small(onPressed: _cargar, child: const Icon(Icons.refresh)),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _pedidos.isEmpty
              ? const EmptyView('No hay pedidos de salón pendientes', icon: Icons.room_service)
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _pedidos.length,
                  itemBuilder: (context, index) {
                    final p = _pedidos[index];
                    final mesas =
                        state.mesas.where((m) => m.intOf('id') == p.mesaId).toList();
                    final mesaLabel = mesas.isEmpty
                        ? 'Sin mesa'
                        : 'Mesa ${mesas.first.str('numero')} · Piso ${mesas.first.intOf('piso')}';
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text('${p.numero} · $mesaLabel',
                                      style: const TextStyle(fontWeight: FontWeight.bold)),
                                ),
                                StatusChip(p.estado),
                              ],
                            ),
                            if (p.incidencia != 'ninguna')
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                    'Incidencia (${p.incidencia}): ${p.pedido.str('incidencia_descripcion')}',
                                    style: const TextStyle(color: Colors.orange)),
                              ),
                            const Divider(),
                            ...p.detalles.map((d) => InfoLine(
                                  '${d.intOf('cantidad')} × ${_nombre(state, d.intOf('producto_id'))}',
                                  d.str('estado_item') == 'reemplazo'
                                      ? 'REEMPLAZO'
                                      : AppFormat.currency(d.doubleOf('subtotal')),
                                )),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                if (p.estado == AppConstants.estadoListo)
                                  OutlinedButton.icon(
                                    onPressed: () async {
                                      await state.run(() => state.repo
                                          .marcarEstado(p.id, AppConstants.estadoEnRuta));
                                      await _cargar();
                                      if (context.mounted) {
                                        showMessage(context, 'Pedido recogido en mostrador');
                                      }
                                    },
                                    icon: const Icon(Icons.shopping_bag_outlined),
                                    label: const Text('Recoger en mostrador'),
                                  ),
                                if (p.estado == AppConstants.estadoEnRuta)
                                  FilledButton.icon(
                                    onPressed: () async {
                                      await state.run(() => state.repo
                                          .marcarEstado(p.id, AppConstants.estadoEntregado));
                                      await _cargar();
                                      if (context.mounted) {
                                        showMessage(context, 'Entregado en mesa');
                                      }
                                    },
                                    icon: const Icon(Icons.check),
                                    label: const Text('Entregar en mesa'),
                                  ),
                                OutlinedButton.icon(
                                  onPressed: () => _reportarIncidencia(context, p.id),
                                  icon: const Icon(Icons.report_problem_outlined),
                                  label: const Text('Reportar incidencia'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () => _cambiarProducto(context, p),
                                  icon: const Icon(Icons.swap_horiz),
                                  label: const Text('Solicitar cambio'),
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

  Future<void> _reportarIncidencia(BuildContext context, int pedidoId) async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reportar incidencia'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Ejemplos: pollo crudo/con sangre, papas en mal estado.'),
            const SizedBox(height: 10),
            TextField(
                controller: controller,
                decoration: const InputDecoration(labelText: 'Descripción'),
                maxLines: 3),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true), child: const Text('Reportar')),
        ],
      ),
    );
    if (ok != true || controller.text.trim().isEmpty) return;
    final state = context.read<AppState>();
    await state
        .run(() => state.repo.reportarIncidencia(pedidoId, controller.text.trim()));
    await _cargar();
    if (context.mounted) {
      showMessage(context, 'Incidencia enviada a caja para validación');
    }
  }

  Future<void> _cambiarProducto(
      BuildContext context, PedidoConDetalle pedido) async {
    final state = context.read<AppState>();
    final List<DbRow> detalles = pedido.detalles;
    if (detalles.isEmpty) return;
    int? detalleId = detalles.first.intOf('id');
    int? productoId;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Solicitar cambio de producto'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                value: detalleId,
                decoration: const InputDecoration(labelText: 'Producto a reemplazar'),
                items: detalles
                    .map((d) => DropdownMenuItem<int>(
                          value: d.intOf('id'),
                          child: Text(_nombre(state, d.intOf('producto_id'))),
                        ))
                    .toList(),
                onChanged: (v) => setLocal(() => detalleId = v),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<int>(
                value: productoId,
                decoration: const InputDecoration(labelText: 'Nuevo producto'),
                items: state.productos
                    .map((p) => DropdownMenuItem<int>(
                          value: p.intOf('id'),
                          child: Text(p.str('nombre')),
                        ))
                    .toList(),
                onChanged: (v) => setLocal(() => productoId = v),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Solicitar')),
          ],
        ),
      ),
    );
    if (ok != true || productoId == null || detalleId == null) return;
    await state.run(() =>
        state.repo.reemplazarProducto(detalleId: detalleId!, productoId: productoId!));
    await _cargar();
    if (context.mounted) {
      showMessage(context, 'Cambio registrado. Caja debe validarlo');
    }
  }

  String _nombre(AppState state, int id) {
    final rows = state.productos.where((p) => p.intOf('id') == id).toList();
    return rows.isEmpty ? 'Producto' : rows.first.str('nombre');
  }
}
