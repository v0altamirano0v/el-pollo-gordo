import 'package:intl/intl.dart';

class AppFormat {
  static final NumberFormat money = NumberFormat.currency(
    locale: 'es_PE',
    symbol: 'S/',
    decimalDigits: 2,
  );

  static final DateFormat date = DateFormat('dd/MM/yyyy');
  static final DateFormat dateTime = DateFormat('dd/MM/yyyy HH:mm');
  static final DateFormat time = DateFormat('HH:mm');
  static final DateFormat iso = DateFormat('yyyy-MM-ddTHH:mm:ss');

  static String currency(num value) => money.format(value);
  static String number(num value) => value.toStringAsFixed(2);

  static String? tryDate(String? value) {
    if (value == null || value.isEmpty) return null;
    try {
      return dateTime.format(DateTime.parse(value).toLocal());
    } catch (_) {
      return value;
    }
  }

  static String hoy() => DateFormat('yyyy-MM-dd').format(DateTime.now());
  static String ahora() => iso.format(DateTime.now());

  static String estado(String estado) {
    switch (estado) {
      case 'registrado':
        return 'Registrado';
      case 'en_preparacion':
        return 'En preparación';
      case 'listo':
        return 'Listo';
      case 'en_ruta':
        return 'En ruta';
      case 'entregado':
        return 'Entregado';
      case 'fallido':
        return 'Entrega fallida';
      case 'devuelto':
        return 'Devuelto';
      case 'cancelado':
        return 'Cancelado';
      case 'pendiente':
        return 'Pendiente';
      case 'asignado':
        return 'Asignado';
      case 'liquidado':
        return 'Liquidado';
      default:
        return estado.replaceAll('_', ' ');
    }
  }
}
