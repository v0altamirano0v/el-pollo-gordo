import '../core/db_client.dart';

extension DbRowX on DbRow {
  int intOf(String key) {
    final v = this[key];
    if (v is int) return v;
    if (v is num) return v.toInt();
    return 0;
  }

  int? intOpt(String key) {
    final v = this[key];
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return null;
  }

  double doubleOf(String key) {
    final v = this[key];
    if (v is num) return v.toDouble();
    return 0;
  }

  String str(String key) => this[key]?.toString() ?? '';

  bool boolOf(String key) {
    final v = this[key];
    if (v is bool) return v;
    return intOf(key) == 1;
  }
}

class CartItem {
  final int productoId;
  final String nombre;
  final double precio;
  final double equivalencia;
  int cantidad;
  String observacion;

  CartItem({
    required this.productoId,
    required this.nombre,
    required this.precio,
    required this.equivalencia,
    this.cantidad = 1,
    this.observacion = '',
  });

  double get subtotal => precio * cantidad;
  double get pollos => equivalencia * cantidad;

  Map<String, Object?> toRow(int pedidoId) => {
        'pedido_id': pedidoId,
        'producto_id': productoId,
        'cantidad': cantidad,
        'precio_unitario': precio,
        'subtotal': subtotal,
        'equivalencia_pollo': equivalencia,
        'observacion': observacion.isEmpty ? null : observacion,
        'estado_item': 'normal',
      };
}

class PedidoConDetalle {
  final DbRow pedido;
  final List<DbRow> detalles;
  final DbRow? entrega;

  PedidoConDetalle({required this.pedido, required this.detalles, this.entrega});

  int get id => pedido.intOf('id');
  String get numero => pedido.str('numero');
  String get estado => pedido.str('estado');
  String get tipo => pedido.str('tipo');
  double get total => pedido.doubleOf('total');
  double get envio => pedido.doubleOf('costo_envio');
  int? get mesaId => pedido.intOpt('mesa_id');
  String get incidencia => pedido.str('estado_incidencia');
  double get pollos => detalles.fold(0, (sum, d) => sum + d.doubleOf('equivalencia_pollo') * d.intOf('cantidad'));
}

class ResumenDia {
  final double ventas;
  final double efectivo;
  final int pedidos;
  final double pollosVendidos;
  final double pollosComprados;
  final double totalCompras;

  const ResumenDia({
    required this.ventas,
    required this.efectivo,
    required this.pedidos,
    required this.pollosVendidos,
    required this.pollosComprados,
    required this.totalCompras,
  });

  double get diferenciaPollos => pollosComprados - pollosVendidos;
}
