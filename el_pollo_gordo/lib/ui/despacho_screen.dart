import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants.dart';
import '../core/db_client.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../models/entities.dart';
import '../state/app_state.dart';
import 'widgets.dart';

class DespachoScreen extends StatefulWidget {
  const DespachoScreen({super.key});

  @override
  State<DespachoScreen> createState() => _DespachoScreenState();
}

class _DespachoScreenState extends State<DespachoScreen> {
  List<PedidoConDetalle> _pedidos = [];
  bool _cargando = true;

  Future<void> _cargar() async {
    final state = context.read<AppState>();
    if (!state.listo) return;
    final rows = await state.repo.pedidos(
      establecimientoId: state.establecimientoId,
      estados: const [
        AppConstants.estadoRegistrado,
        AppConstants.estadoEnPreparacion,
        AppConstants.estadoListo,
      ],
    );
    final lista = <PedidoConDetalle>[];
    for (final row in rows) {
      final pedido = await state.repo.pedidoConDetalle(row.intOf('id'));
      if (pedido != null) lista.add(pedido);
    }
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
      floatingActionButton: FloatingActionButton.small(
        onPressed: _cargar,
        child: const Icon(Icons.refresh),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _pedidos.isEmpty
              ? const EmptyView('No hay pedidos pendientes en cocina', icon: Icons.restaurant_menu)
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _pedidos.length,
                  itemBuilder: (context, index) {
                    final p = _pedidos[index];
                    DbRow? mesa;
                    if (p.mesaId != null) {
                      final mesas = state.mesas
                          .where((m) => m.intOf('id') == p.mesaId)
                          .toList();
                      if (mesas.isNotEmpty) mesa = mesas.first;
                    }
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    p.numero,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                ),
                                StatusChip(p.estado),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${p.tipo == AppConstants.tipoSalon ? 'Salón' : 'Para llevar'}'
                              '${mesa == null ? '' : ' · Mesa ${mesa.str('numero')} (Piso ${mesa.intOf('piso')})'}'
                              ' · ${AppFormat.tryDate(p.pedido.str('fecha')) ?? ''}',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                            ),
                            const Divider(),
                            ...p.detalles.map((d) => InfoLine(
                                  '${d.intOf('cantidad')} × ${_nombreProducto(state, d.intOf('producto_id'))}',
                                  AppFormat.currency(d.doubleOf('subtotal')),
                                )),
                            InfoLine('Total', AppFormat.currency(p.total),
                                valueStyle: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: AppTheme.rojo)),
                            if (p.incidencia != 'ninguna')
                              Container(
                                margin: const EdgeInsets.only(top: 8),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade50,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                    'Incidencia (${p.incidencia}): ${p.pedido.str('incidencia_descripcion')}'),
                              ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                if (p.estado != AppConstants.estadoListo)
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () async {
                                        await state.run(() => state.repo
                                            .marcarEstado(p.id, AppConstants.estadoListo));
                                        await _cargar();
                                        if (context.mounted) {
                                          showMessage(context, '${p.numero} marcado como listo');
                                        }
                                      },
                                      icon: const Icon(Icons.check),
                                      label: const Text('Marcar listo'),
                                    ),
                                  ),
                                if (p.estado == AppConstants.estadoListo &&
                                    p.tipo == AppConstants.tipoParaLlevar) ...[
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: FilledButton.icon(
                                      onPressed: () async {
                                        final ok = await confirmAction(
                                            context,
                                            'Confirmar entrega',
                                            '¿Registrar cobro en efectivo y comprobante de ${p.numero}?');
                                        if (!ok) return;
                                        await state.run(() async {
                                          await state.repo.registrarPago(
                                            pedidoId: p.id,
                                            cajeroId: state.empleadoId!,
                                            monto: p.total,
                                            clienteId: p.pedido.intOpt('cliente_id'),
                                          );
                                          await state.repo
                                              .marcarEstado(p.id, AppConstants.estadoEntregado);
                                        });
                                        await _cargar();
                                        if (context.mounted) {
                                          showMessage(context, 'Entrega confirmada');
                                        }
                                      },
                                      icon: const Icon(Icons.handshake),
                                      label: const Text('Cobrar y entregar'),
                                    ),
                                  ),
                                ],
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

  String _nombreProducto(AppState state, int id) {
    final productos = state.productos.where((p) => p.intOf('id') == id).toList();
    return productos.isEmpty ? 'Producto' : productos.first.str('nombre');
  }
}
