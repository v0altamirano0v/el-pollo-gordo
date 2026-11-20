import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:intl/intl.dart';

import '../core/db_client.dart';
import '../core/format.dart';
import '../models/entities.dart';
import '../state/app_state.dart';
import 'widgets.dart';

class CierreScreen extends StatefulWidget {
  const CierreScreen({super.key});

  @override
  State<CierreScreen> createState() => _CierreScreenState();
}

class _CierreScreenState extends State<CierreScreen> {
  String _fecha = AppFormat.hoy();
  final _observacion = TextEditingController();
  ResumenDia? _resumen;
  List<DbRow> _cierres = [];
  bool _cargando = true;

  Future<void> _cargar() async {
    final state = context.read<AppState>();
    if (!state.listo) return;
    final resumen = await state.repo.resumenDia(state.establecimientoId!, _fecha);
    final cierres = await state.repo.cierres(state.establecimientoId!);
    if (!mounted) return;
    setState(() {
      _resumen = resumen;
      _cierres = cierres;
      _cargando = false;
    });
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(_cargar);
  }

  Future<void> _elegirFecha() async {
    final inicial = DateTime.tryParse(_fecha) ?? DateTime.now();
    final elegida = await showDatePicker(
      context: context,
      initialDate: inicial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (elegida == null) return;
    setState(() => _fecha = DateFormat('yyyy-MM-dd').format(elegida));
    await _cargar();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final r = _resumen;
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.small(onPressed: _cargar, child: const Icon(Icons.refresh)),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SectionCard(
                  title: 'Cierre diario',
                  action: OutlinedButton.icon(
                    onPressed: _elegirFecha,
                    icon: const Icon(Icons.calendar_month),
                    label: Text(_fecha),
                  ),
                  child: r == null
                      ? const EmptyView('Sin información')
                      : Column(
                          children: [
                            InfoLine('Ventas del día', AppFormat.currency(r.ventas)),
                            InfoLine('Efectivo cobrado', AppFormat.currency(r.efectivo)),
                            InfoLine('Pedidos', '${r.pedidos}'),
                            const Divider(),
                            InfoLine('Pollos vendidos', '${r.pollosVendidos.toStringAsFixed(3)}'),
                            InfoLine('Pollos comprados', '${r.pollosComprados.toStringAsFixed(3)}'),
                            InfoLine(
                              'Diferencia (comprados - vendidos)',
                              r.diferenciaPollos.toStringAsFixed(3),
                              valueStyle: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: r.diferenciaPollos < 0 ? Colors.red : Colors.green,
                              ),
                            ),
                            InfoLine('Total compras', AppFormat.currency(r.totalCompras)),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _observacion,
                              decoration: const InputDecoration(labelText: 'Observaciones del cierre'),
                              maxLines: 3,
                            ),
                            const SizedBox(height: 12),
                            FilledButton.icon(
                              onPressed: () async {
                                final ok = await confirmAction(context, 'Generar cierre',
                                    '¿Consolidar la información del ${AppFormat.date.format(DateTime.parse(_fecha))}?');
                                if (!ok) return;
                                await state.run(() => state.repo.cerrarDia(
                                      establecimientoId: state.establecimientoId!,
                                      fecha: _fecha,
                                      usuarioId: state.empleadoId!,
                                      observacion: _observacion.text,
                                    ));
                                _observacion.clear();
                                await _cargar();
                                if (context.mounted) showMessage(context, 'Cierre diario generado');
                              },
                              icon: const Icon(Icons.summarize),
                              label: const Text('Generar cierre diario'),
                            ),
                          ],
                        ),
                ),
                SectionCard(
                  title: 'Cierres registrados',
                  child: _cierres.isEmpty
                      ? const EmptyView('Aún no hay cierres registrados')
                      : Column(
                          children: _cierres.take(10).map((c) => ListTile(
                                leading: const Icon(Icons.description),
                                title: Text('${c.str('fecha')} · ${AppFormat.currency(c.doubleOf('total_ventas'))}'),
                                subtitle: Text(
                                    '${c.intOf('pedidos')} pedidos · ${c.doubleOf('pollos_vendidos').toStringAsFixed(2)} pollos vendidos · dif. ${c.doubleOf('diferencia_pollos').toStringAsFixed(2)}'),
                              )).toList(),
                        ),
                ),
              ],
            ),
    );
  }
}
