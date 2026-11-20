class AppConstants {
  static const String appName = 'El Pollo Gordo';
  static const String appSubtitle = 'Gestión de Ventas · Pisco';
  static const String dbName = 'el_pollo_gordo.db';
  static const int dbVersion = 1;
  static const String webStorageKey = 'el_pollo_gordo_db_v1';
  static const String sessionKey = 'el_pollo_gordo_session_v1';

  static const String principal = 'principal';
  static const String delivery = 'delivery';

  static const String rolCajero = 'cajero';
  static const String rolAdministrador = 'administrador';
  static const String rolMostrador = 'mostrador';
  static const String rolMozo = 'mozo';
  static const String rolCajeroDelivery = 'cajero_delivery';
  static const String rolRepartidor = 'repartidor';
  static const String rolPropietario = 'propietario';

  static const String tipoSalon = 'salon';
  static const String tipoParaLlevar = 'para_llevar';
  static const String tipoDelivery = 'delivery';

  static const String estadoRegistrado = 'registrado';
  static const String estadoEnPreparacion = 'en_preparacion';
  static const String estadoListo = 'listo';
  static const String estadoEnRuta = 'en_ruta';
  static const String estadoEntregado = 'entregado';
  static const String estadoFallido = 'fallido';
  static const String estadoDevuelto = 'devuelto';
  static const String estadoCancelado = 'cancelado';

  static const List<String> roles = [
    rolCajero,
    rolAdministrador,
    rolMostrador,
    rolMozo,
    rolCajeroDelivery,
    rolRepartidor,
    rolPropietario,
  ];

  static String etiquetaRol(String rol) {
    switch (rol) {
      case rolCajero:
        return 'Cajero / Administrador';
      case rolAdministrador:
        return 'Administrador';
      case rolMostrador:
        return 'Mostrador / Despacho';
      case rolMozo:
        return 'Mozo';
      case rolCajeroDelivery:
        return 'Cajero de Delivery';
      case rolRepartidor:
        return 'Repartidor';
      case rolPropietario:
        return 'Propietario';
      default:
        return rol;
    }
  }

  static List<String> rolesParaEstablecimiento(String tipo) {
    if (tipo == delivery) {
      return [rolCajeroDelivery, rolRepartidor, rolPropietario, rolAdministrador];
    }
    return [
      rolCajero,
      rolAdministrador,
      rolMostrador,
      rolMozo,
      rolPropietario,
    ];
  }
}
