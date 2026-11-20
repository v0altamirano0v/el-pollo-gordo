import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants.dart';
import '../core/db_client.dart';
import '../data/database.dart';
import '../data/repositories.dart';
import '../models/entities.dart';

class AppState extends ChangeNotifier {
  late final AppRepository repo;
  DbClient? _db;

  bool listo = false;
  bool dbDisponible = false;
  bool ocupado = false;
  String? error;

  List<DbRow> establecimientos = [];
  List<DbRow> empleados = [];
  List<DbRow> productos = [];
  List<DbRow> mesas = [];
  List<DbRow> clientes = [];
  List<DbRow> repartidores = [];
  List<DbRow> proveedores = [];

  DbRow? establecimiento;
  DbRow? empleado;

  int? get establecimientoId => establecimiento?.intOpt('id');
  int? get empleadoId => empleado?.intOpt('id');
  String get rol => empleado?.str('rol') ?? '';
  bool get esDelivery => establecimiento?.str('tipo') == AppConstants.delivery;
  bool get puedeAutorizar => [
        AppConstants.rolAdministrador,
        AppConstants.rolPropietario,
        AppConstants.rolCajero,
        AppConstants.rolCajeroDelivery,
      ].contains(rol);

  Future<void> init() async {
    if (listo) return;
    try {
      _db = await createAppDatabase().open();
      repo = AppRepository(_db!);
      await _restoreSession();
      await refresh(notify: false);
      dbDisponible = true;
      listo = true;
    } catch (e) {
      error = 'No se pudo iniciar la base de datos: $e';
      listo = true;
    }
    notifyListeners();
  }

  Future<void> _restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final estId = prefs.getInt('${AppConstants.sessionKey}_est');
    final empId = prefs.getInt('${AppConstants.sessionKey}_emp');
    if (estId == null || empId == null) return;
    final ests = await repo.establecimientos();
    final emps = await repo.empleados();
    final est = ests.where((e) => e.intOf('id') == estId).toList();
    final emp = emps.where((e) => e.intOf('id') == empId).toList();
    if (est.isNotEmpty && emp.isNotEmpty) {
      establecimiento = est.first;
      empleado = emp.first;
    }
  }

  Future<void> selectSession(int estId, int empId) async {
    final ests = await repo.establecimientos();
    final emps = await repo.empleados();
    final est = ests.where((e) => e.intOf('id') == estId).toList();
    final emp = emps.where((e) => e.intOf('id') == empId).toList();
    if (est.isEmpty || emp.isEmpty) return;
    establecimiento = est.first;
    empleado = emp.first;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('${AppConstants.sessionKey}_est', estId);
    await prefs.setInt('${AppConstants.sessionKey}_emp', empId);
    await refresh();
  }

  Future<void> logout() async {
    establecimiento = null;
    empleado = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('${AppConstants.sessionKey}_est');
    await prefs.remove('${AppConstants.sessionKey}_emp');
    notifyListeners();
  }

  Future<void> refresh({bool notify = true}) async {
    establecimientos = await repo.establecimientos();
    empleados = await repo.empleados();
    productos = await repo.productos();
    if (establecimientoId != null) {
      mesas = await repo.mesas(establecimientoId!);
      repartidores = await repo.repartidores(establecimientoId!);
    } else {
      mesas = [];
      repartidores = [];
    }
    clientes = await repo.clientes();
    proveedores = await repo.proveedores();
    if (notify) notifyListeners();
  }

  Future<T> run<T>(Future<T> Function() action) async {
    ocupado = true;
    error = null;
    notifyListeners();
    try {
      final result = await action();
      await refresh(notify: false);
      return result;
    } catch (e) {
      error = e.toString();
      notifyListeners();
      rethrow;
    } finally {
      ocupado = false;
      notifyListeners();
    }
  }
}
