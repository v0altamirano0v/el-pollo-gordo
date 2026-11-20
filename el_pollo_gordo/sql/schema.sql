-- =============================================================
-- EL POLLO GORDO - GESTIÓN DE VENTAS (PISCO, PERÚ)
-- Script DDL SQLite / compatible con SQL estándar
-- Versión: 1.0
-- =============================================================

PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS establecimiento (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  codigo TEXT NOT NULL UNIQUE,
  nombre TEXT NOT NULL,
  direccion TEXT NOT NULL,
  tipo TEXT NOT NULL CHECK (tipo IN ('principal','delivery')),
  activo INTEGER NOT NULL DEFAULT 1,
  created_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS empleado (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  codigo TEXT NOT NULL UNIQUE,
  nombre TEXT NOT NULL,
  rol TEXT NOT NULL,
  establecimiento_id INTEGER NOT NULL,
  telefono TEXT,
  activo INTEGER NOT NULL DEFAULT 1,
  FOREIGN KEY (establecimiento_id) REFERENCES establecimiento(id)
);

CREATE TABLE IF NOT EXISTS mesa (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  establecimiento_id INTEGER NOT NULL,
  numero TEXT NOT NULL,
  piso INTEGER NOT NULL DEFAULT 1,
  capacidad INTEGER NOT NULL DEFAULT 4,
  estado TEXT NOT NULL DEFAULT 'libre' CHECK (estado IN ('libre','ocupada','reservada')),
  activo INTEGER NOT NULL DEFAULT 1,
  FOREIGN KEY (establecimiento_id) REFERENCES establecimiento(id),
  UNIQUE (establecimiento_id, numero)
);

CREATE TABLE IF NOT EXISTS cliente (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  nombre TEXT NOT NULL,
  telefono TEXT,
  direccion TEXT,
  referencia TEXT,
  tipo TEXT NOT NULL DEFAULT 'delivery',
  activo INTEGER NOT NULL DEFAULT 1,
  created_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS proveedor (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  nombre TEXT NOT NULL,
  ruc TEXT,
  telefono TEXT,
  direccion TEXT,
  activo INTEGER NOT NULL DEFAULT 1
);

CREATE TABLE IF NOT EXISTS compra_pollo (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  proveedor_id INTEGER NOT NULL,
  establecimiento_id INTEGER NOT NULL,
  fecha TEXT NOT NULL,
  cantidad_pollos INTEGER NOT NULL CHECK (cantidad_pollos > 0),
  costo_unitario REAL NOT NULL CHECK (costo_unitario >= 0),
  total REAL NOT NULL,
  numero_documento TEXT,
  observacion TEXT,
  FOREIGN KEY (proveedor_id) REFERENCES proveedor(id),
  FOREIGN KEY (establecimiento_id) REFERENCES establecimiento(id)
);

CREATE TABLE IF NOT EXISTS categoria (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  nombre TEXT NOT NULL UNIQUE,
  activo INTEGER NOT NULL DEFAULT 1
);

CREATE TABLE IF NOT EXISTS producto (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  categoria_id INTEGER NOT NULL,
  codigo TEXT NOT NULL UNIQUE,
  nombre TEXT NOT NULL,
  precio REAL NOT NULL CHECK (precio >= 0),
  equivalencia_pollo REAL NOT NULL DEFAULT 0 CHECK (equivalencia_pollo >= 0),
  tipo TEXT NOT NULL DEFAULT 'otro',
  activo INTEGER NOT NULL DEFAULT 1,
  FOREIGN KEY (categoria_id) REFERENCES categoria(id)
);

CREATE TABLE IF NOT EXISTS pedido (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  numero TEXT NOT NULL UNIQUE,
  establecimiento_id INTEGER NOT NULL,
  empleado_id INTEGER NOT NULL,
  cliente_id INTEGER,
  mesa_id INTEGER,
  tipo TEXT NOT NULL CHECK (tipo IN ('salon','para_llevar','delivery')),
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
  FOREIGN KEY (mesa_id) REFERENCES mesa(id),
  FOREIGN KEY (incidencia_autorizado_por) REFERENCES empleado(id)
);

CREATE TABLE IF NOT EXISTS detalle_pedido (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  pedido_id INTEGER NOT NULL,
  producto_id INTEGER NOT NULL,
  cantidad INTEGER NOT NULL CHECK (cantidad > 0),
  precio_unitario REAL NOT NULL,
  subtotal REAL NOT NULL,
  equivalencia_pollo REAL NOT NULL DEFAULT 0,
  observacion TEXT,
  estado_item TEXT NOT NULL DEFAULT 'normal',
  FOREIGN KEY (pedido_id) REFERENCES pedido(id),
  FOREIGN KEY (producto_id) REFERENCES producto(id)
);

CREATE TABLE IF NOT EXISTS pago (
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
);

CREATE TABLE IF NOT EXISTS comprobante (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  pago_id INTEGER NOT NULL,
  pedido_id INTEGER NOT NULL,
  tipo TEXT NOT NULL DEFAULT 'boleta',
  numero TEXT NOT NULL UNIQUE,
  fecha TEXT NOT NULL,
  subtotal REAL NOT NULL,
  total REAL NOT NULL,
  cliente_id INTEGER,
  FOREIGN KEY (pago_id) REFERENCES pago(id),
  FOREIGN KEY (pedido_id) REFERENCES pedido(id),
  FOREIGN KEY (cliente_id) REFERENCES cliente(id)
);

CREATE TABLE IF NOT EXISTS entrega_delivery (
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
);

CREATE TABLE IF NOT EXISTS liquidacion_reparto (
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
);

CREATE TABLE IF NOT EXISTS cierre_diario (
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
  FOREIGN KEY (usuario_id) REFERENCES empleado(id),
  UNIQUE (establecimiento_id, fecha)
);

CREATE INDEX IF NOT EXISTS idx_pedido_establecimiento_fecha ON pedido(establecimiento_id, fecha);
CREATE INDEX IF NOT EXISTS idx_pedido_estado ON pedido(estado);
CREATE INDEX IF NOT EXISTS idx_detalle_pedido_pedido ON detalle_pedido(pedido_id);
CREATE INDEX IF NOT EXISTS idx_pago_pedido ON pago(pedido_id);
CREATE INDEX IF NOT EXISTS idx_entrega_repartidor ON entrega_delivery(repartidor_id);
CREATE INDEX IF NOT EXISTS idx_entrega_estado ON entrega_delivery(estado);
CREATE INDEX IF NOT EXISTS idx_liquidacion_estado ON liquidacion_reparto(estado);
CREATE INDEX IF NOT EXISTS idx_compra_fecha ON compra_pollo(fecha);
