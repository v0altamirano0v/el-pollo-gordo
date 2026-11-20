import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants.dart';
import '../core/db_client.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../models/entities.dart';
import '../state/app_state.dart';
import 'widgets.dart';

class DeliveryNuevoScreen extends StatefulWidget {
  const DeliveryNuevoScreen({super.key});

  @override
  State<DeliveryNuevoScreen> createState() => _DeliveryNuevoScreenState();
}

class _DeliveryNuevoScreenState extends State<DeliveryNuevoScreen> {
  final _nombre = TextEditingController();
  final _telefono = TextEditingController();
  final _direccion = TextEditingController();
  final _referencia = TextEditingController();
  final _tarifa = TextEditingController(text: '8.00');
  final _obs = TextEditingController();
  final Map<int, CartItem> _carrito = {};
  List<DbRow> _duplicados = [];
  bool _confirmado = false;
  int? _pedidoId;
  int? _entregaId;
  String? _numero;
  double? _total;
  int? _repartidorSeleccionado;

  double get _subtotal => _carrito.values.fold(0, (s, i) => s + i.subtotal);
  double get _envio => double.tryParse(_tarifa.text.replaceAll(',', '.')) ?? 0;

  void _agregar(DbRow producto) {
    final id = producto.intOf('id');
    setState(() {
      final item = _carrito[id];
      if (item == null) {
        _carrito[id] = CartItem(
          productoId: id,
          nombre: producto.str('nombre'),
          precio: producto.doubleOf('precio'),
          equivalencia: producto.doubleOf('equivalencia_pollo'),
        );
      } else {
        item.cantidad++;
      }
    });
  }

  void _cantidad(int id, int delta) {
    setState(() {
      final item = _carrito[id];
      if (item == null) return;
      item.cantidad += delta;
      if (item.cantidad <= 0) _carrito.remove(id);
    });
  }

  String? _validar() {
    if (_nombre.text.trim().isEmpty) return 'Ingrese el nombre del cliente';
    if (_telefono.text.trim().length < 7) return 'Ingrese un teléfono válido';
    if (_direccion.text.trim().isEmpty) return 'Ingrese la dirección de entrega';
    if (_carrito.isEmpty) return 'Agregue productos al pedido';
    if (_envio < 0) return 'La tarifa de envío no puede ser negativa';
    if (_duplicados.isNotEmpty && !_confirmado) return 'Confirme que el pedido no es duplicado';
    return null;
  }

  Future<void> _buscarDuplicados() async {
    final state = context.read<AppState>();
    final rows = await state.repo.detectarDuplicados(
      telefono: _telefono.text,
      nombre: _nombre.text,
      direccion: _direccion.text,
    );
    setState(() => _duplicados = rows);
    if (context.mounted) {
      showMessage(context, rows.isEmpty ? 'No se encontraron pedidos similares hoy' : 'Se encontraron ${rows.length} pedido(s) similar(es)');
    }
  }

  Future<void> _registrar() async {
    final error = _validar();
    if (error != null) {
      showMessage(context, error, error: true);
      return;
    }
    final state = context.read<AppState>();
    try {
      final creado = await state.run(() => state.repo.crearPedidoDelivery(
            establecimientoId: state.establecimientoId!,
            empleadoId: state.empleadoId!,
            nombre: _nombre.text,
            telefono: _telefono.text,
            direccion: _direccion.text,
            referencia: _referencia.text,
            items: _carrito.values.toList(),
            tarifa: _envio,
            duplicadoSospechoso: _duplicados.isNotEmpty,
            observacion: _obs.text,
          ));
      final pedidos = await state.repo.pedidos(establecimientoId: state.establecimientoId);
      final numero = pedidos.where((p) => p.intOf('id') == creado.pedidoId).first.str('numero');
      setState(() {
        _pedidoId = creado.pedidoId;
        _entregaId = creado.entregaId;
        _numero = numero;
        _total = creado.total;
        _carrito.clear();
        _duplicados = [];
        _confirmado = false;
      });
      if (context.mounted) showMessage(context, 'Pedido $numero creado por ${AppFormat.currency(creado.total)}');
    } catch (e) {
      if (context.mounted) showMessage(context, 'Error: $e', error: true);
    }
  }

  Future<void> _asignar() async {
    if (_entregaId == null || _repartidorSeleccionado == null) return;
    final state = context.read<AppState>();
    await state.run(() => state.repo.asignarRepartidor(
          _entregaId!,
          _repartidorSeleccionado!,
          cajeroId: state.empleadoId,
        ));
    if (context.mounted) showMessage(context, 'Repartidor asignado y pedido en ruta');
    setState(() => _entregaId = null);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionCard(
            title: 'Pedido telefónico',
            child: Column(
              children: [
                TextField(controller: _nombre, decoration: const InputDecoration(labelText: 'Cliente *')),
                const SizedBox(height: 10),
                TextField(controller: _telefono, decoration: const InputDecoration(labelText: 'Teléfono *'), keyboardType: TextInputType.phone),
                const SizedBox(height: 10),
                TextField(controller: _direccion, decoration: const InputDecoration(labelText: 'Dirección *')),
                const SizedBox(height: 10),
                TextField(controller: _referencia, decoration: const InputDecoration(labelText: 'Referencia')),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: TextField(controller: _tarifa, decoration: const InputDecoration(labelText: 'Tarifa de envío'), keyboardType: TextInputType.number)),
                    const SizedBox(width: 10),
                    Expanded(child: OutlinedButton.icon(onPressed: _buscarDuplicados, icon: const Icon(Icons.search), label: const Text('Validar duplicados'))),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(controller: _obs, decoration: const InputDecoration(labelText: 'Observación (opcional)'), maxLines: 2),
              ],
            ),
          ),
          if (_duplicados.isNotEmpty)
            Card(
              color: Colors.orange.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Posibles pedidos duplicados hoy:', style: TextStyle(fontWeight: FontWeight.bold)),
                    ..._duplicados.map((d) => Text('• ${d.str('numero')} · ${AppFormat.currency(d.doubleOf('total'))}')),
                    CheckboxListTile(
                      value: _confirmado,
                      onChanged: (v) => setState(() => _confirmado = v ?? false),
                      title: const Text('Confirmo que es un pedido nuevo y válido'),
                    ),
                  ],
                ),
              ),
            ),
          SectionCard(
            title: 'Productos',
            child: ResponsiveGrid(
              minWidth: 200,
              children: state.productos.map((p) => Card(
                    child: InkWell(
                      onTap: () => _agregar(p),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.str('nombre'), style: const TextStyle(fontWeight: FontWeight.bold)),
                            Text(AppFormat.currency(p.doubleOf('precio')), style: const TextStyle(color: AppTheme.rojo)),
                          ],
                        ),
                      ),
                    ),
                  )).toList(),
            ),
          ),
          SectionCard(
            title: 'Resumen',
            child: Column(
              children: [
                ..._carrito.values.map((i) => ListTile(
                      title: Text('${i.cantidad} × ${i.nombre}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(onPressed: () => _cantidad(i.productoId, -1), icon: const Icon(Icons.remove_circle_outline)),
                          IconButton(onPressed: () => _cantidad(i.productoId, 1), icon: const Icon(Icons.add_circle_outline)),
                          Text(AppFormat.currency(i.subtotal)),
                        ],
                      ),
                    )),
                const Divider(),
                InfoLine('Subtotal', AppFormat.currency(_subtotal)),
                InfoLine('Envío', AppFormat.currency(_envio)),
                InfoLine('Total', AppFormat.currency(_subtotal + _envio),
                    valueStyle: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.rojo, fontSize: 16)),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: state.ocupado ? null : _registrar,
                  icon: const Icon(Icons.add),
                  label: Text(state.ocupado ? 'Registrando...' : 'Registrar pedido'),
                ),
              ],
            ),
          ),
          if (_numero != null)
            Card(
              color: Colors.green.shade50,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Pedido $_numero creado · Total ${AppFormat.currency(_total ?? 0)}',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    if (_entregaId != null) ...[
                      DropdownButtonFormField<int>(
                        value: _repartidorSeleccionado,
                        decoration: const InputDecoration(labelText: 'Repartidor'),
                        items: state.repartidores.map((r) => DropdownMenuItem<int>(
                              value: r.intOf('id'),
                              child: Text(r.str('nombre')),
                            )).toList(),
                        onChanged: (v) => setState(() => _repartidorSeleccionado = v),
                      ),
                      const SizedBox(height: 10),
                      FilledButton.icon(
                        onPressed: _repartidorSeleccionado == null ? null : _asignar,
                        icon: const Icon(Icons.two_wheeler),
                        label: const Text('Asignar y poner en ruta'),
                      ),
                    ] else
                      const Text('Repartidor asignado. Seguimiento disponible en la pantalla de repartos.'),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
