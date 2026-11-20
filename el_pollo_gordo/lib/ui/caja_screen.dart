import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants.dart';
import '../core/db_client.dart';
import '../core/format.dart';
import '../data/schema.dart';
import '../models/entities.dart';
import '../state/app_state.dart';
import 'widgets.dart';

class CajaScreen extends StatefulWidget {
  const CajaScreen({super.key});

  @override
  State<CajaScreen> createState() => _CajaScreenState();
}

class _CajaScreenState extends State<CajaScreen> {
  List<DbRow> _pedidos = [];
  List<DbRow> _pagos = [];
  List<DbRow> _comprobantes = [];
  bool _cargando = true;

  Future<void> _cargar() async {
    final state = context.read<AppState>();
    if (!state.listo) return;
    final pedidos = await state.repo.pedidos(establecimientoId: state.establecimientoId);
    final pagos = await state.repo.db.query(Tables.pago);
    final comprobantes = await state.repo.db.query(Tables.comprobante);
    if (!mounted) return;
    setState(() {
      _pedidos = pedidos;
      _pagos = pagos;
      _comprobantes = comprobantes;
      _cargando = false;
    });
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(_cargar);
  }

  bool _tienePago(int pedidoId) =>
      _pagos.any((p) => p.intOf('pedido_id') == pedidoId && p.str('estado') == 'pagado');

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.small(onPressed: _cargar, child: const Icon(Icons.refresh)),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SectionCard(
                  title: 'Cobros pendientes',
                  child: _pedidos.where((p) => !_tienePago(p.intOf('id')) && p.str('estado') != AppConstants.estadoCancelado).isEmpty
                      ? const EmptyView('Todos los pedidos tienen pago registrado', icon: Icons.payments)
                      : Column(
                          children: _pedidos
                              .where((p) => !_tienePago(p.intOf('id')) && p.str('estado') != AppConstants.estadoCancelado)
                              .map((p) => Card(
                                    child: ListTile(
                                      title: Text('${p.str('numero')} · ${AppFormat.currency(p.doubleOf('total'))}'),
                                      subtitle: Text(
                                          '${p.str('tipo')} · ${AppFormat.estado(p.str('estado'))} · ${AppFormat.tryDate(p.str('fecha')) ?? ''}'),
                                      trailing: FilledButton(
                                        onPressed: () async {
                                          await state.run(() => state.repo.registrarPago(
                                                pedidoId: p.intOf('id'),
                                                cajeroId: state.empleadoId!,
                                                monto: p.doubleOf('total'),
                                                clienteId: p.intOpt('cliente_id'),
                                              ));
                                          await _cargar();
                                          if (context.mounted) showMessage(context, 'Pago y comprobante registrados');
                                        },
                                        child: const Text('Cobrar'),
                                      ),
                                    ),
                                  ))
                              .toList(),
                        ),
                ),
                SectionCard(
                  title: 'Incidencias y devoluciones por validar',
                  child: _pedidos.where((p) => p.str('estado_incidencia') == 'reportada').isEmpty
                      ? const EmptyView('No hay incidencias pendientes', icon: Icons.verified)
                      : Column(
                          children: _pedidos
                              .where((p) => p.str('estado_incidencia') == 'reportada')
                              .map((p) => Card(
                                    color: Colors.orange.shade50,
                                    child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('${p.str('numero')} · ${AppFormat.currency(p.doubleOf('total'))}',
                                              style: const TextStyle(fontWeight: FontWeight.bold)),
                                          const SizedBox(height: 4),
                                          Text(p.str('incidencia_descripcion')),
                                          const SizedBox(height: 10),
                                          Wrap(
                                            spacing: 8,
                                            children: [
                                              FilledButton.icon(
                                                onPressed: () async {
                                                  await state.run(() => state.repo.autorizarIncidencia(
                                                        pedidoId: p.intOf('id'),
                                                        empleadoId: state.empleadoId!,
                                                        aceptar: true,
                                                        observacion: p.str('incidencia_descripcion'),
                                                      ));
                                                  await _cargar();
                                                  if (context.mounted) showMessage(context, 'Incidencia validada');
                                                },
                                                icon: const Icon(Icons.check),
                                                label: const Text('Aceptar cambio'),
                                              ),
                                              OutlinedButton.icon(
                                                onPressed: () async {
                                                  await state.run(() => state.repo.autorizarIncidencia(
                                                        pedidoId: p.intOf('id'),
                                                        empleadoId: state.empleadoId!,
                                                        aceptar: false,
                                                        observacion: 'Reclamo rechazado por caja',
                                                      ));
                                                  await _cargar();
                                                  if (context.mounted) showMessage(context, 'Reclamo rechazado');
                                                },
                                                icon: const Icon(Icons.close),
                                                label: const Text('Rechazar'),
                                              ),
                                              OutlinedButton.icon(
                                                onPressed: () async {
                                                  final ok = await confirmAction(context, 'Devolución',
                                                      '¿Registrar devolución del pedido ${p.str('numero')}?');
                                                  if (!ok) return;
                                                  await state.run(() async {
                                                    await state.repo.marcarEstado(p.intOf('id'), AppConstants.estadoDevuelto);
                                                    await state.repo.db.update(Tables.pago, {'estado': 'devuelto'},
                                                        where: {'pedido_id': p.intOf('id')});
                                                  });
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
                                  ))
                              .toList(),
                        ),
                ),
                SectionCard(
                  title: 'Comprobantes emitidos (${_comprobantes.length})',
                  child: _comprobantes.isEmpty
                      ? const EmptyView('Aún no hay comprobantes')
                      : Column(
                          children: _comprobantes.take(10).map((c) => ListTile(
                                leading: const Icon(Icons.receipt_long),
                                title: Text('${c.str('tipo').toUpperCase()} ${c.str('numero')}'),
                                subtitle: Text('Pedido ${c.intOf('pedido_id')} · ${AppFormat.currency(c.doubleOf('total'))}'),
                              )).toList(),
                        ),
                ),
              ],
            ),
    );
  }
}
