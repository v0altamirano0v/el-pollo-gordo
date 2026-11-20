import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/db_client.dart';
import '../core/format.dart';
import '../models/entities.dart';
import '../state/app_state.dart';
import 'widgets.dart';

class LiquidacionScreen extends StatefulWidget {
  const LiquidacionScreen({super.key});

  @override
  State<LiquidacionScreen> createState() => _LiquidacionScreenState();
}

class _LiquidacionScreenState extends State<LiquidacionScreen> {
  List<DbRow> _pendientes = [];
  final Map<int, TextEditingController> _rendido = {};
  final Map<int, DbRow> _entregas = {};
  final Map<int, DbRow> _pedidos = {};
  bool _cargando = true;

  int? _proveedorId;
  final _cantidad = TextEditingController(text: '20');
  final _costo = TextEditingController(text: '18.50');
  final _documento = TextEditingController();
  final _observacion = TextEditingController();

  Future<void> _cargar() async {
    final state = context.read<AppState>();
    if (!state.listo) return;
    final pendientes = await state.repo.liquidaciones(estado: 'pendiente');
    final entregas = await state.repo.db.query('entrega_delivery');
    final pedidos = await state.repo.pedidos(tipo: 'delivery');
    final entMap = <int, DbRow>{};
    for (final e in entregas) {
      entMap[e.intOf('id')] = e;
      if (!_rendido.containsKey(e.intOf('id'))) {
        _rendido[e.intOf('id')] = TextEditingController(
          text: e.doubleOf('monto_cobrado').toStringAsFixed(2),
        );
      }
    }
    final pedMap = <int, DbRow>{};
    for (final p in pedidos) {
      pedMap[p.intOf('id')] = p;
    }
    if (!mounted) return;
    setState(() {
      _pendientes = pendientes;
      _entregas.clear();
      _entregas.addAll(entMap);
      _pedidos.clear();
      _pedidos.addAll(pedMap);
      _cargando = false;
    });
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(_cargar);
  }

  String _nombre(AppState state, List<DbRow> rows, int? id) {
    if (id == null) return '-';
    final found = rows.where((r) => r.intOf('id') == id);
    return found.isEmpty ? '$id' : found.first.str('nombre');
  }

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
                  title: 'Liquidación de efectivo de repartidores',
                  child: _pendientes.isEmpty
                      ? const EmptyView('No hay efectivo pendiente de liquidar', icon: Icons.account_balance_wallet_outlined)
                      : Column(
                          children: _pendientes.map((l) {
                            final entrega = _entregas[l.intOf('entrega_id')];
                            final pedido = entrega == null ? null : _pedidos[entrega.intOf('pedido_id')];
                            final esperado = l.doubleOf('esperado');
                            final controller = _rendido[l.intOf('entrega_id')] ??=
                                TextEditingController(text: '0.00');
                            final rendido = double.tryParse(controller.text.replaceAll(',', '.')) ?? 0;
                            return Card(
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Text('Pedido ${pedido?.str('numero') ?? l.intOf('entrega_id')}',
                                        style: const TextStyle(fontWeight: FontWeight.bold)),
                                    InfoLine('Repartidor', _nombre(state, state.empleados, l.intOpt('repartidor_id'))),
                                    InfoLine('Esperado', AppFormat.currency(esperado)),
                                    TextField(
                                      controller: controller,
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(labelText: 'Efectivo rendido'),
                                      onChanged: (_) => setState(() {}),
                                    ),
                                    const SizedBox(height: 6),
                                    InfoLine(
                                      'Diferencia',
                                      AppFormat.currency(esperado - rendido),
                                      valueStyle: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: (esperado - rendido).abs() < 0.01 ? Colors.green : Colors.red,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    FilledButton.icon(
                                      onPressed: () async {
                                        await state.run(() => state.repo.liquidarReparto(
                                              liquidacionId: l.intOf('id'),
                                              rendido: rendido,
                                              cajeroId: state.empleadoId!,
                                              observacion: 'Efectivo recibido en caja',
                                            ));
                                        await _cargar();
                                        if (context.mounted) showMessage(context, 'Liquidación registrada');
                                      },
                                      icon: const Icon(Icons.check),
                                      label: const Text('Liquidar'),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                ),
                SectionCard(
                  title: 'Compra de pollos a proveedores',
                  child: Column(
                    children: [
                      DropdownButtonFormField<int>(
                        value: _proveedorId,
                        decoration: const InputDecoration(labelText: 'Proveedor'),
                        items: state.proveedores.map((p) => DropdownMenuItem<int>(
                              value: p.intOf('id'),
                              child: Text(p.str('nombre')),
                            )).toList(),
                        onChanged: (v) => setState(() => _proveedorId = v),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(child: TextField(controller: _cantidad, decoration: const InputDecoration(labelText: 'Cantidad de pollos'), keyboardType: TextInputType.number)),
                          const SizedBox(width: 10),
                          Expanded(child: TextField(controller: _costo, decoration: const InputDecoration(labelText: 'Costo unitario'), keyboardType: TextInputType.number)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextField(controller: _documento, decoration: const InputDecoration(labelText: 'N.° de documento')),
                      const SizedBox(height: 10),
                      TextField(controller: _observacion, decoration: const InputDecoration(labelText: 'Observación (opcional)')),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _proveedorId == null
                            ? null
                            : () async {
                                final cantidad = int.tryParse(_cantidad.text) ?? 0;
                                final costo = double.tryParse(_costo.text.replaceAll(',', '.')) ?? 0;
                                if (cantidad <= 0 || costo <= 0) {
                                  showMessage(context, 'Ingrese cantidad y costo válidos', error: true);
                                  return;
                                }
                                await state.run(() => state.repo.registrarCompraPollo(
                                      proveedorId: _proveedorId!,
                                      establecimientoId: state.establecimientoId!,
                                      cantidad: cantidad,
                                      costoUnitario: costo,
                                      numeroDocumento: _documento.text,
                                      observacion: _observacion.text,
                                    ));
                                _documento.clear();
                                _observacion.clear();
                                if (context.mounted) showMessage(context, 'Compra registrada');
                              },
                        icon: const Icon(Icons.shopping_cart),
                        label: const Text('Registrar compra'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
