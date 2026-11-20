import '../core/db_client.dart';

class Tables {
  static const establecimiento = 'establecimiento';
  static const empleado = 'empleado';
  static const mesa = 'mesa';
  static const cliente = 'cliente';
  static const proveedor = 'proveedor';
  static const compraPollo = 'compra_pollo';
  static const categoria = 'categoria';
  static const producto = 'producto';
  static const pedido = 'pedido';
  static const detallePedido = 'detalle_pedido';
  static const pago = 'pago';
  static const comprobante = 'comprobante';
  static const entregaDelivery = 'entrega_delivery';
  static const liquidacionReparto = 'liquidacion_reparto';
  static const cierreDiario = 'cierre_diario';

  static const all = [
    establecimiento,
    empleado,
    mesa,
    cliente,
    proveedor,
    compraPollo,
    categoria,
    producto,
    pedido,
    detallePedido,
    pago,
    comprobante,
    entregaDelivery,
    liquidacionReparto,
    cierreDiario,
  ];
}

const List<String> schemaStatements = [
  '''CREATE TABLE IF NOT EXISTS establecimiento (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    codigo TEXT NOT NULL UNIQUE,
    nombre TEXT NOT NULL,
    direccion TEXT NOT NULL,
    tipo TEXT NOT NULL,
    activo INTEGER NOT NULL DEFAULT 1,
    created_at TEXT NOT NULL
  )''',
  '''CREATE TABLE IF NOT EXISTS empleado (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    codigo TEXT NOT NULL UNIQUE,
    nombre TEXT NOT NULL,
    rol TEXT NOT NULL,
    establecimiento_id INTEGER NOT NULL,
    telefono TEXT,
    activo INTEGER NOT NULL DEFAULT 1,
    FOREIGN KEY (establecimiento_id) REFERENCES establecimiento(id)
  )''',
  '''CREATE TABLE IF NOT EXISTS mesa (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    establecimiento_id INTEGER NOT NULL,
    numero TEXT NOT NULL,
    piso INTEGER NOT NULL DEFAULT 1,
    capacidad INTEGER NOT NULL DEFAULT 4,
    estado TEXT NOT NULL DEFAULT 'libre',
    activo INTEGER NOT NULL DEFAULT 1,
    FOREIGN KEY (establecimiento_id) REFERENCES establecimiento(id)
  )''',
  '''CREATE TABLE IF NOT EXISTS cliente (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    nombre TEXT NOT NULL,
    telefono TEXT,
    direccion TEXT,
    referencia TEXT,
    tipo TEXT NOT NULL DEFAULT 'delivery',
    activo INTEGER NOT NULL DEFAULT 1,
    created_at TEXT NOT NULL
  )''',
  '''CREATE TABLE IF NOT EXISTS proveedor (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    nombre TEXT NOT NULL,
    ruc TEXT,
    telefono TEXT,
    direccion TEXT,
    activo INTEGER NOT NULL DEFAULT 1
  )''',
  '''CREATE TABLE IF NOT EXISTS compra_pollo (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    proveedor_id INTEGER NOT NULL,
    establecimiento_id INTEGER NOT NULL,
    fecha TEXT NOT NULL,
    cantidad_pollos INTEGER NOT NULL,
    costo_unitario REAL NOT NULL,
    total REAL NOT NULL,
    numero_documento TEXT,
    observacion TEXT,
    FOREIGN KEY (proveedor_id) REFERENCES proveedor(id),
    FOREIGN KEY (establecimiento_id) REFERENCES establecimiento(id)
  )''',
  '''CREATE TABLE IF NOT EXISTS categoria (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    nombre TEXT NOT NULL UNIQUE,
    activo INTEGER NOT NULL DEFAULT 1
  )''',
  '''CREATE TABLE IF NOT EXISTS producto (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    categoria_id INTEGER NOT NULL,
    codigo TEXT NOT NULL UNIQUE,
    nombre TEXT NOT NULL,
    precio REAL NOT NULL,
    equivalencia_pollo REAL NOT NULL DEFAULT 0,
    tipo TEXT NOT NULL DEFAULT 'otro',
    activo INTEGER NOT NULL DEFAULT 1,
    FOREIGN KEY (categoria_id) REFERENCES categoria(id)
  )''',
  '''CREATE TABLE IF NOT EXISTS pedido (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    numero TEXT NOT NULL UNIQUE,
    establecimiento_id INTEGER NOT NULL,
    empleado_id INTEGER NOT NULL,
    cliente_id INTEGER,
    mesa_id INTEGER,
    tipo TEXT NOT NULL,
    estado TEXT NOT NULL DEFAULT 'registrado',
    canal TEXT NOT NULL DEFAULT 'mostrador',
    fecha TEXT NOT NULL,
    total REAL NOT NULL DEFAULT 0,
    costo_envio REAL NOT NULL DEFAULT 0,
    observacion TEXT,
    estado_incidencia TEXT NOT NULL DEFAULT 'ninguna',
    incidencia_descripcion TEXT,
    incidencia_autorizado_por INTEGER,
    incidencia_autorizado_at TEXT,
    FOREIGN KEY (establecimiento_id) REFERENCES establecimiento(id),
    FOREIGN KEY (empleado_id) REFERENCES empleado(id),
    FOREIGN KEY (cliente_id) REFERENCES cliente(id),
    FOREIGN KEY (mesa_id) REFERENCES mesa(id)
  )''',
  '''CREATE TABLE IF NOT EXISTS detalle_pedido (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    pedido_id INTEGER NOT NULL,
    producto_id INTEGER NOT NULL,
    cantidad INTEGER NOT NULL,
    precio_unitario REAL NOT NULL,
    subtotal REAL NOT NULL,
    equivalencia_pollo REAL NOT NULL DEFAULT 0,
    observacion TEXT,
    estado_item TEXT NOT NULL DEFAULT 'normal',
    FOREIGN KEY (pedido_id) REFERENCES pedido(id),
    FOREIGN KEY (producto_id) REFERENCES producto(id)
  )''',
  '''CREATE TABLE IF NOT EXISTS pago (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    pedido_id INTEGER NOT NULL,
    fecha TEXT NOT NULL,
    monto REAL NOT NULL,
    metodo TEXT NOT NULL DEFAULT 'efectivo',
    estado TEXT NOT NULL DEFAULT 'pendiente',
    referencia TEXT,
    cajero_id INTEGER NOT NULL,
    FOREIGN KEY (pedido_id) REFERENCES pedido(id),
    FOREIGN KEY (cajero_id) REFERENCES empleado(id)
  )''',
  '''CREATE TABLE IF NOT EXISTS comprobante (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    pago_id INTEGER NOT NULL,
    pedido_id INTEGER NOT NULL,
    tipo TEXT NOT NULL DEFAULT 'boleta',
    numero TEXT NOT NULL,
    fecha TEXT NOT NULL,
    subtotal REAL NOT NULL,
    total REAL NOT NULL,
    cliente_id INTEGER,
    FOREIGN KEY (pago_id) REFERENCES pago(id),
    FOREIGN KEY (pedido_id) REFERENCES pedido(id),
    FOREIGN KEY (cliente_id) REFERENCES cliente(id)
  )''',
  '''CREATE TABLE IF NOT EXISTS entrega_delivery (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    pedido_id INTEGER NOT NULL,
    cliente_id INTEGER NOT NULL,
    telefono TEXT NOT NULL,
    direccion TEXT NOT NULL,
    referencia TEXT,
    repartidor_id INTEGER,
    estado TEXT NOT NULL DEFAULT 'pendiente',
    tarifa REAL NOT NULL DEFAULT 0,
    fecha_asignacion TEXT,
    fecha_salida TEXT,
    fecha_entrega TEXT,
    intentos_contacto INTEGER NOT NULL DEFAULT 0,
    monto_cobrado REAL NOT NULL DEFAULT 0,
    observacion TEXT,
    incidencia TEXT,
    es_duplicado_sospechoso INTEGER NOT NULL DEFAULT 0,
    FOREIGN KEY (pedido_id) REFERENCES pedido(id),
    FOREIGN KEY (cliente_id) REFERENCES cliente(id),
    FOREIGN KEY (repartidor_id) REFERENCES empleado(id)
  )''',
  '''CREATE TABLE IF NOT EXISTS liquidacion_reparto (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    entrega_id INTEGER NOT NULL,
    repartidor_id INTEGER NOT NULL,
    fecha TEXT NOT NULL,
    esperado REAL NOT NULL,
    rendido REAL NOT NULL DEFAULT 0,
    diferencia REAL NOT NULL DEFAULT 0,
    estado TEXT NOT NULL DEFAULT 'pendiente',
    observacion TEXT,
    cajero_id INTEGER NOT NULL,
    FOREIGN KEY (entrega_id) REFERENCES entrega_delivery(id),
    FOREIGN KEY (repartidor_id) REFERENCES empleado(id),
    FOREIGN KEY (cajero_id) REFERENCES empleado(id)
  )''',
  '''CREATE TABLE IF NOT EXISTS cierre_diario (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    establecimiento_id INTEGER NOT NULL,
    fecha TEXT NOT NULL,
    total_ventas REAL NOT NULL DEFAULT 0,
    total_efectivo REAL NOT NULL DEFAULT 0,
    pedidos INTEGER NOT NULL DEFAULT 0,
    pollos_vendidos REAL NOT NULL DEFAULT 0,
    pollos_comprados REAL NOT NULL DEFAULT 0,
    diferencia_pollos REAL NOT NULL DEFAULT 0,
    total_compras REAL NOT NULL DEFAULT 0,
    observacion TEXT,
    usuario_id INTEGER NOT NULL,
    created_at TEXT NOT NULL,
    FOREIGN KEY (establecimiento_id) REFERENCES establecimiento(id),
    FOREIGN KEY (usuario_id) REFERENCES empleado(id)
  )''',
];

Future<void> seedDatabase(DbClient db) async {
  final establecimientos = await db.query(Tables.establecimiento);
  if (establecimientos.isNotEmpty) return;

  {
    final principalId = await db.insert(Tables.establecimiento, {
      'codigo': 'LOCAL-01',
      'nombre': 'El Pollo Gordo - Local Principal',
      'direccion': 'Las Américas 965, Pisco',
      'tipo': 'principal',
      'activo': 1,
      'created_at': DateTime.now().toIso8601String(),
    });
    final deliveryId = await db.insert(Tables.establecimiento, {
      'codigo': 'DEL-01',
      'nombre': 'El Pollo Gordo - Delivery',
      'direccion': 'Av. Camino Real, Pisco',
      'tipo': 'delivery',
      'activo': 1,
      'created_at': DateTime.now().toIso8601String(),
    });

    final empleados = <String, int>{};
    final empleadosData = [
      ('EMP-001', 'María Quispe', 'cajero', principalId),
      ('EMP-002', 'Carlos Rojas', 'administrador', principalId),
      ('EMP-003', 'Lucy Huamán', 'mostrador', principalId),
      ('EMP-004', 'Diego Salas', 'mozo', principalId),
      ('EMP-005', 'Ana Torres', 'cajero_delivery', deliveryId),
      ('EMP-006', 'Jorge Flores', 'repartidor', deliveryId),
      ('EMP-007', 'Rosa Mendoza', 'repartidor', deliveryId),
      ('EMP-008', 'Pedro Paredes', 'propietario', principalId),
    ];
    for (final e in empleadosData) {
      empleados[e.$1] = await db.insert(Tables.empleado, {
        'codigo': e.$1,
        'nombre': e.$2,
        'rol': e.$3,
        'establecimiento_id': e.$4,
        'telefono': '9${DateTime.now().millisecond.toString().padLeft(8, '0')}',
        'activo': 1,
      });
    }

    for (final m in [
      {'numero': '01', 'piso': 1, 'capacidad': 4},
      {'numero': '02', 'piso': 1, 'capacidad': 4},
      {'numero': '03', 'piso': 1, 'capacidad': 6},
      {'numero': '04', 'piso': 2, 'capacidad': 4},
      {'numero': '05', 'piso': 2, 'capacidad': 6},
      {'numero': '06', 'piso': 2, 'capacidad': 8},
    ]) {
      await db.insert(Tables.mesa, {
        ...m,
        'establecimiento_id': principalId,
        'estado': 'libre',
        'activo': 1,
      });
    }

    final clienteId = await db.insert(Tables.cliente, {
      'nombre': 'Cliente Mostrador',
      'telefono': '',
      'direccion': '',
      'referencia': '',
      'tipo': 'mostrador',
      'activo': 1,
      'created_at': DateTime.now().toIso8601String(),
    });
    final clienteDelivery1 = await db.insert(Tables.cliente, {
      'nombre': 'Familia Ríos',
      'telefono': '987654321',
      'direccion': 'Av. San Clemente 123',
      'referencia': 'Casa azul',
      'tipo': 'delivery',
      'activo': 1,
      'created_at': DateTime.now().toIso8601String(),
    });
    final clienteDelivery2 = await db.insert(Tables.cliente, {
      'nombre': 'Señora Elena',
      'telefono': '956123456',
      'direccion': 'Jr. Piura 456',
      'referencia': 'Frente a la bodega',
      'tipo': 'delivery',
      'activo': 1,
      'created_at': DateTime.now().toIso8601String(),
    });

    final proveedorId = await db.insert(Tables.proveedor, {
      'nombre': 'Granja Don Andrés',
      'ruc': '10456789012',
      'telefono': '978123456',
      'direccion': 'Pisco - Perú',
      'activo': 1,
    });
    await db.insert(Tables.compraPollo, {
      'proveedor_id': proveedorId,
      'establecimiento_id': principalId,
      'fecha': AppSeed.hoy,
      'cantidad_pollos': 30,
      'costo_unitario': 18.5,
      'total': 555.0,
      'numero_documento': 'B001-000123',
      'observacion': 'Compra inicial de pollo a la brasa',
    });

    final catPollo = await db.insert(Tables.categoria, {'nombre': 'Pollo a la brasa', 'activo': 1});
    final catAcomp = await db.insert(Tables.categoria, {'nombre': 'Acompañamientos', 'activo': 1});
    final catCremas = await db.insert(Tables.categoria, {'nombre': 'Cremas y salsas', 'activo': 1});
    final catBebidas = await db.insert(Tables.categoria, {'nombre': 'Bebidas', 'activo': 1});

    final productos = [
      (catPollo, 'POL-18', 'Pollo 1/8', 22.0, 0.125, 'pollo'),
      (catPollo, 'POL-14', 'Pollo 1/4', 39.0, 0.25, 'pollo'),
      (catPollo, 'POL-12', 'Pollo 1/2', 72.0, 0.5, 'pollo'),
      (catPollo, 'POL-01', 'Pollo entero', 138.0, 1.0, 'pollo'),
      (catAcomp, 'PAP-01', 'Papas fritas', 14.0, 0.0, 'papas'),
      (catAcomp, 'ENS-01', 'Ensalada', 10.0, 0.0, 'ensalada'),
      (catCremas, 'CRE-01', 'Crema de ají', 3.0, 0.0, 'crema'),
      (catCremas, 'CRE-02', 'Crema de huacatay', 3.0, 0.0, 'crema'),
      (catBebidas, 'BEB-01', 'Gaseosa 1.5L', 14.0, 0.0, 'bebida'),
    ];
    final productoIds = <String, int>{};
    for (final p in productos) {
      productoIds[p.$2] = await db.insert(Tables.producto, {
        'categoria_id': p.$1,
        'codigo': p.$2,
        'nombre': p.$3,
        'precio': p.$4,
        'equivalencia_pollo': p.$5,
        'tipo': p.$6,
        'activo': 1,
      });
    }
    final ahora = DateTime.now().toIso8601String();

    final pedidoSalon = await db.insert(Tables.pedido, {
      'numero': 'S-DEMO-001',
      'establecimiento_id': principalId,
      'empleado_id': empleados['EMP-001']!,
      'cliente_id': clienteId,
      'mesa_id': 1,
      'tipo': 'salon',
      'estado': 'listo',
      'canal': 'salon',
      'fecha': ahora,
      'total': 53.0,
      'costo_envio': 0,
      'observacion': 'Pedido de demostración para salón',
      'estado_incidencia': 'ninguna',
    });
    await db.insert(Tables.detallePedido, {
      'pedido_id': pedidoSalon,
      'producto_id': productoIds['POL-14']!,
      'cantidad': 1,
      'precio_unitario': 39.0,
      'subtotal': 39.0,
      'equivalencia_pollo': 0.25,
      'estado_item': 'normal',
    });
    await db.insert(Tables.detallePedido, {
      'pedido_id': pedidoSalon,
      'producto_id': productoIds['PAP-01']!,
      'cantidad': 1,
      'precio_unitario': 14.0,
      'subtotal': 14.0,
      'equivalencia_pollo': 0,
      'estado_item': 'normal',
    });

    final pedidoLlevar = await db.insert(Tables.pedido, {
      'numero': 'L-DEMO-002',
      'establecimiento_id': principalId,
      'empleado_id': empleados['EMP-001']!,
      'cliente_id': clienteId,
      'mesa_id': null,
      'tipo': 'para_llevar',
      'estado': 'registrado',
      'canal': 'mostrador',
      'fecha': ahora,
      'total': 63.0,
      'costo_envio': 0,
      'observacion': 'Pedido de demostración para llevar',
      'estado_incidencia': 'ninguna',
    });
    await db.insert(Tables.detallePedido, {
      'pedido_id': pedidoLlevar,
      'producto_id': productoIds['POL-12']!,
      'cantidad': 1,
      'precio_unitario': 72.0,
      'subtotal': 72.0,
      'equivalencia_pollo': 0.5,
      'estado_item': 'normal',
    });
    await db.update(Tables.pedido, {'total': 72.0}, where: {'id': pedidoLlevar});

    final pedidoDelivery = await db.insert(Tables.pedido, {
      'numero': 'D-DEMO-003',
      'establecimiento_id': deliveryId,
      'empleado_id': empleados['EMP-005']!,
      'cliente_id': clienteDelivery1,
      'mesa_id': null,
      'tipo': 'delivery',
      'estado': 'en_ruta',
      'canal': 'telefono',
      'fecha': ahora,
      'total': 61.0,
      'costo_envio': 8.0,
      'observacion': 'Pedido de demostración delivery',
      'estado_incidencia': 'ninguna',
    });
    await db.insert(Tables.detallePedido, {
      'pedido_id': pedidoDelivery,
      'producto_id': productoIds['POL-14']!,
      'cantidad': 1,
      'precio_unitario': 39.0,
      'subtotal': 39.0,
      'equivalencia_pollo': 0.25,
      'estado_item': 'normal',
    });
    await db.insert(Tables.detallePedido, {
      'pedido_id': pedidoDelivery,
      'producto_id': productoIds['PAP-01']!,
      'cantidad': 1,
      'precio_unitario': 14.0,
      'subtotal': 14.0,
      'equivalencia_pollo': 0,
      'estado_item': 'normal',
    });
    final entregaDemo = await db.insert(Tables.entregaDelivery, {
      'pedido_id': pedidoDelivery,
      'cliente_id': clienteDelivery1,
      'telefono': '987654321',
      'direccion': 'Av. San Clemente 123',
      'referencia': 'Casa azul',
      'repartidor_id': empleados['EMP-006']!,
      'estado': 'en_ruta',
      'tarifa': 8.0,
      'fecha_asignacion': ahora,
      'fecha_salida': ahora,
      'intentos_contacto': 1,
      'monto_cobrado': 0,
      'incidencia': null,
      'es_duplicado_sospechoso': 0,
    });
    await db.insert(Tables.liquidacionReparto, {
      'entrega_id': entregaDemo,
      'repartidor_id': empleados['EMP-006']!,
      'fecha': ahora,
      'esperado': 61.0,
      'rendido': 0,
      'diferencia': 61.0,
      'estado': 'pendiente',
      'observacion': 'Liquidación pendiente del pedido de demostración',
      'cajero_id': empleados['EMP-005']!,
    });

    AppSeed.clienteId = clienteId;
    AppSeed.clienteDelivery1 = clienteDelivery1;
    AppSeed.clienteDelivery2 = clienteDelivery2;
    AppSeed.proveedorId = proveedorId;
    AppSeed.productoIds = productoIds;
    AppSeed.empleados = empleados;
    AppSeed.principalId = principalId;
    AppSeed.deliveryId = deliveryId;
  }
}

class AppSeed {
  static String get hoy => DateTime.now().toIso8601String().substring(0, 10);
  static int clienteId = 1;
  static int clienteDelivery1 = 2;
  static int clienteDelivery2 = 3;
  static int proveedorId = 1;
  static int principalId = 1;
  static int deliveryId = 2;
  static Map<String, int> productoIds = {};
  static Map<String, int> empleados = {};
}
