import '../core/constants.dart';
import '../core/db_client.dart';
import '../core/format.dart';
import '../data/schema.dart';
import '../models/entities.dart';

class DeliveryCreado {
  final int pedidoId;
  final int entregaId;
  final double total;
  final bool duplicadoSospechoso;

  const DeliveryCreado({
    required this.pedidoId,
    required this.entregaId,
    required this.total,
    required this.duplicadoSospechoso,
  });
}

class AppRepository {
  final DbClient db;

  AppRepository(this.db);

  Future<List<DbRow>> establecimientos() =>
      db.query(Tables.establecimiento, orderBy: const [DbOrder('id')]);

  Future<List<DbRow>> empleados({int? establecimientoId, String? rol}) async {
    final where = <String, Object?>{
      if (establecimientoId != null) 'establecimiento_id': establecimientoId,
      if (rol != null) 'rol': rol,
    };
    return db.query(Tables.empleado, where: where, orderBy: const [DbOrder('nombre')]);
  }

  Future<List<DbRow>> repartidores(int establecimientoId) =>
      empleados(establecimientoId: establecimientoId, rol: AppConstants.rolRepartidor);

  Future<List<DbRow>> mesas(int establecimientoId) => db.query(
        Tables.mesa,
        where: {'establecimiento_id': establecimientoId},
        orderBy: const [DbOrder('piso'), DbOrder('numero')],
      );

  Future<List<DbRow>> productos() =>
      db.query(Tables.producto, where: {'activo': 1}, orderBy: const [DbOrder('nombre')]);

  Future<List<DbRow>> clientes() =>
      db.query(Tables.cliente, orderBy: const [DbOrder('nombre')]);

  Future<List<DbRow>> proveedores() =>
      db.query(Tables.proveedor, where: {'activo': 1}, orderBy: const [DbOrder('nombre')]);

  Future<List<DbRow>> pedidos({
    int? establecimientoId,
    String? tipo,
    List<String>? estados,
    String? fecha,
    int? limit,
  }) async {
    final where = <String, Object?>{
      if (establecimientoId != null) 'establecimiento_id': establecimientoId,
      if (tipo != null) 'tipo': tipo,
    };
    final rows = await db.query(
      Tables.pedido,
      where: where,
      orderBy: const [DbOrder('id', SortDir.desc)],
    );
    return rows.where((row) {
      if (estados != null && !estados.contains(row.str('estado'))) return false;
      if (fecha != null && !row.str('fecha').startsWith(fecha)) return false;
      return true;
    }).take(limit ?? rows.length).toList();
  }

  Future<List<DbRow>> detalles(int pedidoId) => db.query(
        Tables.detallePedido,
        where: {'pedido_id': pedidoId},
        orderBy: const [DbOrder('id')],
      );

  Future<PedidoConDetalle?> pedidoConDetalle(int pedidoId) async {
    final rows = await db.query(Tables.pedido, where: {'id': pedidoId}, limit: 1);
    if (rows.isEmpty) return null;
    final entregas = await db.query(Tables.entregaDelivery, where: {'pedido_id': pedidoId});
    return PedidoConDetalle(
      pedido: rows.first,
      detalles: await detalles(pedidoId),
      entrega: entregas.isEmpty ? null : entregas.first,
    );
  }

  Future<List<PedidoConDetalle>> pedidosConDetalle({
    int? establecimientoId,
    String? tipo,
    List<String>? estados,
    String? fecha,
  }) async {
    final rows = await pedidos(
      establecimientoId: establecimientoId,
      tipo: tipo,
      estados: estados,
      fecha: fecha,
    );
    final result = <PedidoConDetalle>[];
    for (final row in rows) {
      final pedido = await pedidoConDetalle(row.intOf('id'));
      if (pedido != null) result.add(pedido);
    }
    return result;
  }

  Future<List<DbRow>> entregas({int? repartidorId, List<String>? estados}) async {
    final rows = await db.query(
      Tables.entregaDelivery,
      where: {
        if (repartidorId != null) 'repartidor_id': repartidorId,
      },
      orderBy: const [DbOrder('id', SortDir.desc)],
    );
    if (estados == null) return rows;
    return rows.where((r) => estados.contains(r.str('estado'))).toList();
  }

  Future<DbRow?> entregaDePedido(int pedidoId) async {
    final rows = await db.query(Tables.entregaDelivery, where: {'pedido_id': pedidoId}, limit: 1);
    return rows.isEmpty ? null : rows.first;
  }

  Future<List<DbRow>> liquidaciones({String? estado, int? repartidorId}) async {
    final rows = await db.query(
      Tables.liquidacionReparto,
      where: {
        if (repartidorId != null) 'repartidor_id': repartidorId,
      },
      orderBy: const [DbOrder('id', SortDir.desc)],
    );
    if (estado == null) return rows;
    return rows.where((r) => r.str('estado') == estado).toList();
  }

  Future<List<DbRow>> cierres(int establecimientoId) => db.query(
        Tables.cierreDiario,
        where: {'establecimiento_id': establecimientoId},
        orderBy: const [DbOrder('id', SortDir.desc)],
      );

  Future<String> nextNumero(String tipo, [DbClient? client]) async {
    final source = client ?? db;
    final prefix = switch (tipo) {
      AppConstants.tipoSalon => 'S',
      AppConstants.tipoParaLlevar => 'L',
      _ => 'D',
    };
    final base = '$prefix-${AppFormat.hoy()}-';
    final rows = await source.query(Tables.pedido, orderBy: const [DbOrder('id')]);
    var max = 0;
    for (final row in rows) {
      final numero = row.str('numero');
      if (!numero.startsWith(base)) continue;
      final sufijo = int.tryParse(numero.substring(base.length)) ?? 0;
      if (sufijo > max) max = sufijo;
    }
    return '$base${(max + 1).toString().padLeft(4, '0')}';
  }

  Future<List<DbRow>> detectarDuplicados({
    required String telefono,
    required String nombre,
    required String direccion,
  }) async {
    final clientes = await db.query(Tables.cliente);
    final coincides = clientes.where((c) {
      final t = c.str('telefono').replaceAll(RegExp(r'\D'), '');
      final tBuscado = telefono.replaceAll(RegExp(r'\D'), '');
      final mismoTelefono = tBuscado.isNotEmpty && t == tBuscado;
      final mismoNombre = nombre.trim().isNotEmpty &&
          c.str('nombre').toLowerCase() == nombre.trim().toLowerCase();
      final mismaDireccion = direccion.trim().isNotEmpty &&
          c.str('direccion').toLowerCase() == direccion.trim().toLowerCase();
      return mismoTelefono || (mismoNombre && mismaDireccion);
    }).toList();
    final ids = coincides.map((c) => c.intOf('id')).toList();
    if (ids.isEmpty) return [];
    final pedidosHoy = await pedidos(tipo: AppConstants.tipoDelivery, fecha: AppFormat.hoy());
    return pedidosHoy.where((p) => ids.contains(p.intOpt('cliente_id'))).toList();
  }

  Future<int> registrarPedido({
    required String tipo,
    required int establecimientoId,
    required int empleadoId,
    required List<CartItem> items,
    int? clienteId,
    int? mesaId,
    String canal = 'mostrador',
    double envio = 0,
    String observacion = '',
    bool duplicadoSospechoso = false,
    String estadoInicial = AppConstants.estadoRegistrado,
  }) {
    return db.transaction((tx) => insertPedido(
          tx,
          tipo: tipo,
          establecimientoId: establecimientoId,
          empleadoId: empleadoId,
          items: items,
          clienteId: clienteId,
          mesaId: mesaId,
          canal: canal,
          envio: envio,
          observacion: observacion,
          estadoInicial: estadoInicial,
        ));
  }

  Future<int> insertPedido(
    DbClient tx, {
    required String tipo,
    required int establecimientoId,
    required int empleadoId,
    required List<CartItem> items,
    int? clienteId,
    int? mesaId,
    String canal = 'mostrador',
    double envio = 0,
    String observacion = '',
    String estadoInicial = AppConstants.estadoRegistrado,
  }) async {
    final numero = await nextNumero(tipo, tx);
    final subtotal = items.fold<double>(0, (sum, i) => sum + i.subtotal);
    final pedidoId = await tx.insert(Tables.pedido, {
      'numero': numero,
      'establecimiento_id': establecimientoId,
      'empleado_id': empleadoId,
      'cliente_id': clienteId,
      'mesa_id': mesaId,
      'tipo': tipo,
      'estado': estadoInicial,
      'canal': canal,
      'fecha': AppFormat.ahora(),
      'total': subtotal + envio,
      'costo_envio': envio,
      'observacion': observacion.isEmpty ? null : observacion,
      'estado_incidencia': 'ninguna',
    });
    for (final item in items) {
      await tx.insert(Tables.detallePedido, item.toRow(pedidoId));
    }
    if (mesaId != null) {
      await tx.update(Tables.mesa, {'estado': 'ocupada'}, where: {'id': mesaId});
    }
    return pedidoId;
  }

  Future<int> registrarPago({
    required int pedidoId,
    required int cajeroId,
    required double monto,
    int? clienteId,
    String tipoComprobante = 'boleta',
  }) {
    return db.transaction((tx) async {
      final existentes = await tx.query(Tables.pago, where: {'pedido_id': pedidoId});
      if (existentes.isNotEmpty) return existentes.first.intOf('id');
      final pedidoRows = await tx.query(Tables.pedido, where: {'id': pedidoId}, limit: 1);
      final pedido = pedidoRows.first;
      final ahora = AppFormat.ahora();
      final pagoId = await tx.insert(Tables.pago, {
        'pedido_id': pedidoId,
        'fecha': ahora,
        'monto': monto,
        'metodo': 'efectivo',
        'estado': 'pagado',
        'referencia': 'EFECTIVO-${DateTime.now().millisecondsSinceEpoch}',
        'cajero_id': cajeroId,
      });
      await tx.insert(Tables.comprobante, {
        'pago_id': pagoId,
        'pedido_id': pedidoId,
        'tipo': tipoComprobante,
        'numero': 'C${DateTime.now().millisecondsSinceEpoch}',
        'fecha': ahora,
        'subtotal': monto - pedido.doubleOf('costo_envio'),
        'total': monto,
        'cliente_id': clienteId ?? pedido.intOpt('cliente_id'),
      });
      final mesaId = pedido.intOpt('mesa_id');
      if (mesaId != null) {
        await tx.update(Tables.mesa, {'estado': 'libre'}, where: {'id': mesaId});
      }
      return pagoId;
    });
  }

  Future<void> marcarEstado(int pedidoId, String estado) =>
      db.update(Tables.pedido, {'estado': estado}, where: {'id': pedidoId});

  Future<void> reportarIncidencia(int pedidoId, String descripcion) => db.update(Tables.pedido, {
        'estado_incidencia': 'reportada',
        'incidencia_descripcion': descripcion,
      }, where: {'id': pedidoId});

  Future<void> autorizarIncidencia({
    required int pedidoId,
    required int empleadoId,
    required bool aceptar,
    String observacion = '',
  }) async {
    final estadoActual = await pedidoStateAfterIncident(pedidoId);
    await db.update(Tables.pedido, {
      'estado_incidencia': aceptar ? 'validada' : 'rechazada',
      'incidencia_descripcion': observacion.isEmpty ? null : observacion,
      'incidencia_autorizado_por': empleadoId,
      'incidencia_autorizado_at': AppFormat.ahora(),
      'estado': aceptar ? estadoActual : AppConstants.estadoDevuelto,
    }, where: {'id': pedidoId});
  }

  Future<String> pedidoStateAfterIncident(int pedidoId) async {
    final rows = await db.query(Tables.pedido, where: {'id': pedidoId}, limit: 1);
    return rows.isEmpty ? AppConstants.estadoEntregado : rows.first.str('estado');
  }

  Future<void> reemplazarProducto({
    required int detalleId,
    required int productoId,
  }) async {
    final productos = await db.query(Tables.producto, where: {'id': productoId}, limit: 1);
    if (productos.isEmpty) return;
    final producto = productos.first;
    final detalles = await db.query(Tables.detallePedido, where: {'id': detalleId}, limit: 1);
    if (detalles.isEmpty) return;
    final detalle = detalles.first;
    final cantidad = detalle.intOf('cantidad');
    final nuevoSubtotal = producto.doubleOf('precio') * cantidad;
    await db.update(Tables.detallePedido, {
      'producto_id': productoId,
      'precio_unitario': producto.doubleOf('precio'),
      'subtotal': nuevoSubtotal,
      'equivalencia_pollo': producto.doubleOf('equivalencia_pollo'),
      'estado_item': 'reemplazo',
    }, where: {'id': detalleId});
    await recalcularTotal(detalle.intOf('pedido_id'));
  }

  Future<void> recalcularTotal(int pedidoId) async {
    final items = await detalles(pedidoId);
    final pedidoRows = await db.query(Tables.pedido, where: {'id': pedidoId}, limit: 1);
    if (pedidoRows.isEmpty) return;
    final subtotal = items.fold<double>(0, (s, i) => s + i.doubleOf('subtotal'));
    await db.update(Tables.pedido, {
      'total': subtotal + pedidoRows.first.doubleOf('costo_envio'),
    }, where: {'id': pedidoId});
  }

  Future<DeliveryCreado> crearPedidoDelivery({
    required int establecimientoId,
    required int empleadoId,
    required String nombre,
    required String telefono,
    required String direccion,
    required String referencia,
    required List<CartItem> items,
    required double tarifa,
    required bool duplicadoSospechoso,
    int? clienteId,
    String observacion = '',
  }) {
    return db.transaction((tx) async {
      final clienteFinal = clienteId ?? await tx.insert(Tables.cliente, {
            'nombre': nombre.trim(),
            'telefono': telefono.trim(),
            'direccion': direccion.trim(),
            'referencia': referencia.trim(),
            'tipo': 'delivery',
            'activo': 1,
            'created_at': AppFormat.ahora(),
          });
      final pedidoId = await insertPedido(
        tx,
        tipo: AppConstants.tipoDelivery,
        establecimientoId: establecimientoId,
        empleadoId: empleadoId,
        clienteId: clienteFinal,
        items: items,
        canal: 'telefono',
        envio: tarifa,
        observacion: [
          if (duplicadoSospechoso) 'Posible pedido duplicado - validar por teléfono',
          if (observacion.trim().isNotEmpty) observacion.trim(),
        ].join(' | '),
      );
      final entregaId = await tx.insert(Tables.entregaDelivery, {
        'pedido_id': pedidoId,
        'cliente_id': clienteFinal,
        'telefono': telefono.trim(),
        'direccion': direccion.trim(),
        'referencia': referencia.isEmpty ? null : referencia,
        'repartidor_id': null,
        'estado': 'pendiente',
        'tarifa': tarifa,
        'intentos_contacto': 0,
        'monto_cobrado': 0,
        'es_duplicado_sospechoso': duplicadoSospechoso ? 1 : 0,
      });
      final pedidoRows = await tx.query(Tables.pedido, where: {'id': pedidoId}, limit: 1);
      return DeliveryCreado(
        pedidoId: pedidoId,
        entregaId: entregaId,
        total: pedidoRows.first.doubleOf('total'),
        duplicadoSospechoso: duplicadoSospechoso,
      );
    });
  }

  Future<void> asignarRepartidor(int entregaId, int repartidorId, {int? cajeroId}) async {
    final entregas = await db.query(Tables.entregaDelivery, where: {'id': entregaId}, limit: 1);
    if (entregas.isEmpty) return;
    final pedidoId = entregas.first.intOf('pedido_id');
    final pedidoRows = await db.query(Tables.pedido, where: {'id': pedidoId}, limit: 1);
    final ahora = AppFormat.ahora();
    await db.update(Tables.entregaDelivery, {
      'repartidor_id': repartidorId,
      'estado': 'asignado',
      'fecha_asignacion': ahora,
    }, where: {'id': entregaId});
    await db.update(Tables.pedido, {
      'estado': AppConstants.estadoEnRuta,
    }, where: {'id': pedidoId});
    final liquidaciones = await db.query(
      Tables.liquidacionReparto,
      where: {'entrega_id': entregaId},
    );
    if (liquidaciones.isEmpty) {
      await db.insert(Tables.liquidacionReparto, {
        'entrega_id': entregaId,
        'repartidor_id': repartidorId,
        'fecha': ahora,
        'esperado': pedidoRows.isEmpty ? 0 : pedidoRows.first.doubleOf('total'),
        'rendido': 0,
        'diferencia': pedidoRows.isEmpty ? 0 : pedidoRows.first.doubleOf('total'),
        'estado': 'pendiente',
        'observacion': 'Pendiente hasta que el repartidor rinda el efectivo',
        'cajero_id': cajeroId ?? repartidorId,
      });
    }
  }

  Future<void> reasignarRepartidor(int entregaId, int repartidorId, String motivo) async {
    await asignarRepartidor(entregaId, repartidorId);
    await db.update(Tables.entregaDelivery, {
      'observacion': motivo,
      'estado': 'asignado',
      'fecha_salida': null,
    }, where: {'id': entregaId});
  }

  Future<void> marcarSalida(int entregaId) => db.update(Tables.entregaDelivery, {
        'estado': 'en_ruta',
        'fecha_salida': AppFormat.ahora(),
      }, where: {'id': entregaId});

  Future<void> registrarIntentoContacto(int entregaId) async {
    final rows = await db.query(Tables.entregaDelivery, where: {'id': entregaId}, limit: 1);
    final intentos = rows.isEmpty ? 0 : rows.first.intOf('intentos_contacto');
    await db.update(Tables.entregaDelivery, {
      'intentos_contacto': intentos + 1,
    }, where: {'id': entregaId});
  }

  Future<void> registrarEntregaDelivery({
    required int entregaId,
    required double cobrado,
    String observacion = '',
    String incidencia = '',
  }) {
    return db.transaction((tx) async {
      final entregas = await tx.query(Tables.entregaDelivery, where: {'id': entregaId}, limit: 1);
      if (entregas.isEmpty) return;
      final entrega = entregas.first;
      final pedidoId = entrega.intOf('pedido_id');
      final pedidoRows = await tx.query(Tables.pedido, where: {'id': pedidoId}, limit: 1);
      final total = pedidoRows.isEmpty ? cobrado : pedidoRows.first.doubleOf('total');
      final ahora = AppFormat.ahora();
      await tx.insert(Tables.pago, {
        'pedido_id': pedidoId,
        'fecha': ahora,
        'monto': cobrado,
        'metodo': 'efectivo',
        'estado': 'pagado',
        'referencia': 'DELIVERY-${DateTime.now().millisecondsSinceEpoch}',
        'cajero_id': entrega.intOpt('repartidor_id') ?? 1,
      });
      final pagoId = (await tx.query(Tables.pago, where: {'pedido_id': pedidoId})).last.intOf('id');
      await tx.insert(Tables.comprobante, {
        'pago_id': pagoId,
        'pedido_id': pedidoId,
        'tipo': 'boleta',
        'numero': 'D${DateTime.now().millisecondsSinceEpoch}',
        'fecha': ahora,
        'subtotal': cobrado - entrega.doubleOf('tarifa'),
        'total': cobrado,
        'cliente_id': entrega.intOpt('cliente_id'),
      });
      await tx.update(Tables.entregaDelivery, {
        'estado': 'entregado',
        'fecha_entrega': ahora,
        'monto_cobrado': cobrado,
        'observacion': observacion.isEmpty ? null : observacion,
        'incidencia': incidencia.isEmpty ? null : incidencia,
      }, where: {'id': entregaId});
      await tx.update(Tables.pedido, {
        'estado': AppConstants.estadoEntregado,
      }, where: {'id': pedidoId});
      final liquidaciones = await tx.query(
        Tables.liquidacionReparto,
        where: {'entrega_id': entregaId},
      );
      if (liquidaciones.isEmpty) {
        await tx.insert(Tables.liquidacionReparto, {
          'entrega_id': entregaId,
          'repartidor_id': entrega.intOpt('repartidor_id') ?? 1,
          'fecha': ahora,
          'esperado': total,
          'rendido': cobrado,
          'diferencia': total - cobrado,
          'estado': 'pendiente',
          'observacion': 'Cobro registrado por repartidor',
          'cajero_id': entrega.intOpt('repartidor_id') ?? 1,
        });
      } else {
        await tx.update(Tables.liquidacionReparto, {
          'esperado': total,
          'rendido': cobrado,
          'diferencia': total - cobrado,
          'estado': 'pendiente',
        }, where: {'entrega_id': entregaId});
      }
    });
  }

  Future<void> registrarEntregaFallida({
    required int entregaId,
    required String motivo,
    required String accion,
  }) async {
    await db.update(Tables.entregaDelivery, {
      'estado': accion == 'devolver' ? 'devuelto' : 'fallido',
      'incidencia': motivo,
      'observacion': accion,
      'fecha_entrega': AppFormat.ahora(),
    }, where: {'id': entregaId});
    final entregaRows = await db.query(Tables.entregaDelivery, where: {'id': entregaId}, limit: 1);
    if (entregaRows.isEmpty) return;
    await db.update(Tables.pedido, {
      'estado': accion == 'devolver' ? AppConstants.estadoDevuelto : AppConstants.estadoFallido,
      'estado_incidencia': 'reportada',
      'incidencia_descripcion': motivo,
    }, where: {'id': entregaRows.first.intOf('pedido_id')});
  }

  Future<void> liquidarReparto({
    required int liquidacionId,
    required double rendido,
    required int cajeroId,
    String observacion = '',
  }) async {
    final rows = await db.query(Tables.liquidacionReparto, where: {'id': liquidacionId}, limit: 1);
    if (rows.isEmpty) return;
    final esperado = rows.first.doubleOf('esperado');
    await db.update(Tables.liquidacionReparto, {
      'rendido': rendido,
      'diferencia': esperado - rendido,
      'estado': 'liquidado',
      'observacion': observacion,
      'cajero_id': cajeroId,
    }, where: {'id': liquidacionId});
  }

  Future<int> registrarCompraPollo({
    required int proveedorId,
    required int establecimientoId,
    required int cantidad,
    required double costoUnitario,
    required String numeroDocumento,
    String observacion = '',
  }) =>
      db.insert(Tables.compraPollo, {
        'proveedor_id': proveedorId,
        'establecimiento_id': establecimientoId,
        'fecha': AppFormat.ahora(),
        'cantidad_pollos': cantidad,
        'costo_unitario': costoUnitario,
        'total': cantidad * costoUnitario,
        'numero_documento': numeroDocumento,
        'observacion': observacion.isEmpty ? null : observacion,
      });

  Future<List<DbRow>> compras({int? establecimientoId, String? fecha}) async {
    final rows = await db.query(
      Tables.compraPollo,
      where: {
        if (establecimientoId != null) 'establecimiento_id': establecimientoId,
      },
      orderBy: const [DbOrder('id', SortDir.desc)],
    );
    if (fecha == null) return rows;
    return rows.where((r) => r.str('fecha').startsWith(fecha)).toList();
  }

  Future<ResumenDia> resumenDia(int establecimientoId, String fecha) async {
    final pedidosDia = await pedidos(establecimientoId: establecimientoId, fecha: fecha);
    final ids = pedidosDia.map((p) => p.intOf('id')).toList();
    final ventas = pedidosDia.fold<double>(0, (s, p) => s + p.doubleOf('total'));
    final pagos = await db.query(Tables.pago, where: {'estado': 'pagado'});
    final efectivo = pagos.where((p) => ids.contains(p.intOf('pedido_id'))).fold<double>(
          0,
          (s, p) => s + p.doubleOf('monto'),
        );
    final detalles = await db.query(Tables.detallePedido);
    final pollosVendidos = detalles
        .where((d) => ids.contains(d.intOf('pedido_id')))
        .fold<double>(0, (s, d) => s + d.doubleOf('equivalencia_pollo') * d.intOf('cantidad'));
    final comprasDia = await compras(establecimientoId: establecimientoId, fecha: fecha);
    final pollosComprados = comprasDia.fold<double>(0, (s, c) => s + c.intOf('cantidad_pollos'));
    final totalCompras = comprasDia.fold<double>(0, (s, c) => s + c.doubleOf('total'));
    return ResumenDia(
      ventas: ventas,
      efectivo: efectivo,
      pedidos: pedidosDia.length,
      pollosVendidos: pollosVendidos,
      pollosComprados: pollosComprados,
      totalCompras: totalCompras,
    );
  }

  Future<int> cerrarDia({
    required int establecimientoId,
    required String fecha,
    required int usuarioId,
    String observacion = '',
  }) async {
    final r = await resumenDia(establecimientoId, fecha);
    return db.insert(Tables.cierreDiario, {
      'establecimiento_id': establecimientoId,
      'fecha': fecha,
      'total_ventas': r.ventas,
      'total_efectivo': r.efectivo,
      'pedidos': r.pedidos,
      'pollos_vendidos': r.pollosVendidos,
      'pollos_comprados': r.pollosComprados,
      'diferencia_pollos': r.diferenciaPollos,
      'total_compras': r.totalCompras,
      'observacion': observacion.isEmpty ? null : observacion,
      'usuario_id': usuarioId,
      'created_at': AppFormat.ahora(),
    });
  }
}
