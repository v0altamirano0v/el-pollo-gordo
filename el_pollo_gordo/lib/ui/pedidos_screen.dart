import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants.dart';
import '../core/db_client.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../models/entities.dart';
import '../state/app_state.dart';
import 'widgets.dart';

class PedidosScreen extends StatefulWidget {
  const PedidosScreen({super.key});

  @override
  State<PedidosScreen> createState() => _PedidosScreenState();
}

class _PedidosScreenState extends State<PedidosScreen> {
  String _tipo = AppConstants.tipoParaLlevar;
  int? _mesaId;
  final Map<int, CartItem> _carrito = {};
  final TextEditingController _obs = TextEditingController();
  String? _ultimoNumero;

  double get _subtotal => _carrito.values.fold(0, (s, i) => s + i.subtotal);
  double get _pollos => _carrito.values.fold(0, (s, i) => s + i.pollos);

  void _agregar(DbRow producto) {
    final id = producto.intOf('id');
    setState(() {
      final actual = _carrito[id];
      if (actual == null) {
        _carrito[id] = CartItem(
          productoId: id,
          nombre: producto.str('nombre'),
          precio: producto.doubleOf('precio'),
          equivalencia: producto.doubleOf('equivalencia_pollo'),
        );
      } else {
        actual.cantidad++;
      }
    });
  }

  void _cambiarCantidad(int id, int delta) {
    setState(() {
      final item = _carrito[id];
      if (item == null) return;
      item.cantidad += delta;
      if (item.cantidad <= 0) _carrito.remove(id);
    });
  }

  Future<void> _registrar({required bool cobrar}) async {
    final state = context.read<AppState>();
    if (_carrito.isEmpty) {
      showMessage(context, 'Agregue al menos un producto', error: true);
      return;
    }
    if (_tipo == AppConstants.tipoSalon && _mesaId == null) {
      showMessage(context, 'Seleccione una mesa', error: true);
      return;
    }
    final cliente = state.clientes.where((c) => c.str('tipo') == 'mostrador');
    final clienteId = cliente.isEmpty ? null : cliente.first.intOf('id');
    try {
      final pedidoId = await state.run(() => state.repo.registrarPedido(
            tipo: _tipo,
            establecimientoId: state.establecimientoId!,
            empleadoId: state.empleadoId!,
            clienteId: clienteId,
            mesaId: _tipo == AppConstants.tipoSalon ? _mesaId : null,
            items: _carrito.values.toList(),
            observacion: _obs.text,
          ));
      final rows = await state.repo.pedidos(establecimientoId: state.establecimientoId);
      final numero = rows.where((p) => p.intOf('id') == pedidoId).first.str('numero');
      if (cobrar) {
        await state.run(() => state.repo.registrarPago(
              pedidoId: pedidoId,
              cajeroId: state.empleadoId!,
              monto: _subtotal,
              clienteId: clienteId,
            ));
      }
      setState(() {
        _ultimoNumero = numero;
        _carrito.clear();
        _mesaId = null;
        _obs.clear();
      });
      if (context.mounted) {
        showMessage(context, 'Pedido $numero registrado${cobrar ? ' y cobrado' : ''}');
      }
    } catch (e) {
      if (context.mounted) showMessage(context, 'Error: $e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final productos = state.productos;
    final mesasLibres = state.mesas.where((m) => m.str('estado') == 'libre').toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionCard(
            title: 'Nuevo pedido',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: AppConstants.tipoParaLlevar, label: Text('Para llevar'), icon: Icon(Icons.shopping_bag)),
                    ButtonSegment(value: AppConstants.tipoSalon, label: Text('Salón'), icon: Icon(Icons.restaurant)),
                  ],
                  selected: {_tipo},
                  onSelectionChanged: (v) => setState(() => _tipo = v.first),
                ),
                if (_tipo == AppConstants.tipoSalon) ...[
                  const SizedBox(height: 16),
                  Text('Mesa', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: mesasLibres.map((m) => ChoiceChip(
                          label: Text('Piso ${m.intOf('piso')} · Mesa ${m.str('numero')}'),
                          selected: _mesaId == m.intOf('id'),
                          onSelected: (_) => setState(() => _mesaId = m.intOf('id')),
                        )).toList(),
                  ),
                  if (mesasLibres.isEmpty) const Text('No hay mesas libres', style: TextStyle(color: Colors.orange)),
                ],
                const SizedBox(height: 16),
                TextField(
                  controller: _obs,
                  decoration: const InputDecoration(labelText: 'Observación (opcional)'),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          SectionCard(
            title: 'Productos · equivalencia de pollo',
            child: ResponsiveGrid(
              minWidth: 210,
              children: productos.map((p) {
                return Card(
                  color: Colors.white,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _agregar(p),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.str('nombre'), style: const TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(AppFormat.currency(p.doubleOf('precio')), style: const TextStyle(color: Colors.red)),
                          Text(
                            p.doubleOf('equivalencia_pollo') > 0
                                ? 'Equivale a ${p.doubleOf('equivalencia_pollo').toStringAsFixed(3)} pollo'
                                : 'Sin consumo de pollo',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                          ),
                          const Spacer(),
                          const Align(
                            alignment: Alignment.bottomRight,
                            child: Icon(Icons.add_circle, color: AppTheme.rojo),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          SectionCard(
            title: 'Carrito (${_carrito.length} productos)',
            child: _carrito.isEmpty
                ? const EmptyView('Toque un producto para agregarlo')
                : Column(
                    children: [
                      ..._carrito.values.map((item) => ListTile(
                            title: Text(item.nombre),
                            subtitle: Text(
                                '${AppFormat.currency(item.precio)} · ${item.pollos.toStringAsFixed(3)} pollo(s)'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(onPressed: () => _cambiarCantidad(item.productoId, -1), icon: const Icon(Icons.remove_circle_outline)),
                                Text('${item.cantidad}'),
                                IconButton(onPressed: () => _cambiarCantidad(item.productoId, 1), icon: const Icon(Icons.add_circle_outline)),
                              ],
                            ),
                          )),
                      const Divider(),
                      InfoLine('Subtotal', AppFormat.currency(_subtotal)),
                      InfoLine('Equivalencia pollo', '${_pollos.toStringAsFixed(3)} pollo(s)'),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: state.ocupado ? null : () => _registrar(cobrar: false),
                              icon: const Icon(Icons.save),
                              label: const Text('Solo registrar'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: state.ocupado ? null : () => _registrar(cobrar: true),
                              icon: const Icon(Icons.payments),
                              label: const Text('Registrar y cobrar'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
          ),
          if (_ultimoNumero != null)
            Card(
              color: Colors.green.shade50,
              child: ListTile(
                leading: const Icon(Icons.check_circle, color: Colors.green),
                title: Text('Último pedido: $_ultimoNumero'),
                subtitle: const Text('Disponible en Despacho y Caja')),
              ),
            ),
        ],
      ),
    );
  }
}
