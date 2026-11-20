import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../models/entities.dart';
import '../state/app_state.dart';
import 'caja_screen.dart';
import 'cierre_screen.dart';
import 'delivery_asignacion_screen.dart';
import 'delivery_nuevo_screen.dart';
import 'despacho_screen.dart';
import 'liquidacion_screen.dart';
import 'pedidos_screen.dart';
import 'productos_screen.dart';
import 'repartidor_screen.dart';
import 'salon_screen.dart';

enum ScreenKey {
  pedidos,
  despacho,
  salon,
  caja,
  deliveryNuevo,
  deliveryAsignar,
  repartidor,
  liquidacion,
  cierre,
  productos,
}

class _Item {
  final ScreenKey key;
  final String label;
  final IconData icon;

  const _Item(this.key, this.label, this.icon);
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  ScreenKey _actual = ScreenKey.pedidos;

  List<_Item> _items(AppState state) {
    final rol = state.rol;
    final items = <_Item>[];
    if (state.esDelivery) {
      if (rol == AppConstants.rolRepartidor) {
        items.add(const _Item(ScreenKey.repartidor, 'Mis entregas', Icons.two_wheeler));
      } else {
        items.addAll(const [
          _Item(ScreenKey.deliveryNuevo, 'Nuevo pedido', Icons.add_shopping_cart),
          _Item(ScreenKey.deliveryAsignar, 'Repartos', Icons.local_shipping),
          _Item(ScreenKey.liquidacion, 'Liquidación', Icons.account_balance_wallet),
          _Item(ScreenKey.cierre, 'Cierre diario', Icons.summarize),
        ]);
      }
    } else {
      switch (rol) {
        case AppConstants.rolMostrador:
          items.add(const _Item(ScreenKey.despacho, 'Despacho', Icons.restaurant_menu));
          break;
        case AppConstants.rolMozo:
          items.add(const _Item(ScreenKey.salon, 'Salón / Mesas', Icons.room_service));
          break;
        case AppConstants.rolPropietario:
          items.addAll(const [
            _Item(ScreenKey.pedidos, 'Pedidos', Icons.receipt_long),
            _Item(ScreenKey.liquidacion, 'Liquidación', Icons.account_balance_wallet),
            _Item(ScreenKey.cierre, 'Cierre diario', Icons.summarize),
          ]);
          break;
        default:
          items.addAll(const [
            _Item(ScreenKey.pedidos, 'Pedidos', Icons.receipt_long),
            _Item(ScreenKey.despacho, 'Despacho', Icons.restaurant_menu),
            _Item(ScreenKey.caja, 'Caja', Icons.payments),
            _Item(ScreenKey.liquidacion, 'Liquidación', Icons.account_balance_wallet),
            _Item(ScreenKey.cierre, 'Cierre diario', Icons.summarize),
            _Item(ScreenKey.productos, 'Productos', Icons.fastfood),
          ]);
      }
    }
    if (items.isEmpty) {
      items.add(const _Item(ScreenKey.productos, 'Productos', Icons.fastfood));
    }
    return items;
  }

  Widget _content(ScreenKey key) => switch (key) {
        ScreenKey.pedidos => const PedidosScreen(),
        ScreenKey.despacho => const DespachoScreen(),
        ScreenKey.salon => const SalonScreen(),
        ScreenKey.caja => const CajaScreen(),
        ScreenKey.deliveryNuevo => const DeliveryNuevoScreen(),
        ScreenKey.deliveryAsignar => const DeliveryAsignacionScreen(),
        ScreenKey.repartidor => const RepartidorScreen(),
        ScreenKey.liquidacion => const LiquidacionScreen(),
        ScreenKey.cierre => const CierreScreen(),
        ScreenKey.productos => const ProductosScreen(),
      };

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final items = _items(state);
    if (!items.any((i) => i.key == _actual)) {
      _actual = items.first.key;
    }
    final titulo = items.firstWhere((i) => i.key == _actual).label;
    final establecimiento = state.establecimiento?.str('nombre') ?? '';
    final empleado = state.empleado?.str('nombre') ?? '';

    final drawer = Drawer(
      child: SafeArea(
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(color: AppTheme.rojo),
              accountName: Text(empleado),
              accountEmail: Text('${AppConstants.etiquetaRol(state.rol)} · $establecimiento'),
              currentAccountPicture: const CircleAvatar(
                backgroundColor: AppTheme.mostaza,
                child: Icon(Icons.restaurant, color: AppTheme.rojo),
              ),
            ),
            ...items.map((i) => ListTile(
                  leading: Icon(i.icon),
                  title: Text(i.label),
                  selected: i.key == _actual,
                  onTap: () {
                    setState(() => _actual = i.key);
                    Navigator.pop(context);
                  },
                )),
            const Spacer(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Cambiar de rol'),
              onTap: () async {
                await state.logout();
                if (context.mounted) Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final ancho = constraints.maxWidth;
        if (ancho >= 900) {
          return Scaffold(
            appBar: AppBar(
              title: Text('${AppConstants.appName} · $titulo'),
              actions: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Center(
                    child: Text(
                      '$empleado · ${AppConstants.etiquetaRol(state.rol)}',
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ),
                ),
                IconButton(tooltip: 'Cambiar de rol', onPressed: state.logout, icon: const Icon(Icons.logout)),
              ],
            ),
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: items.indexWhere((i) => i.key == _actual),
                  onDestinationSelected: (index) => setState(() => _actual = items[index].key),
                  labelType: NavigationRailLabelType.all,
                  leading: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Icon(Icons.restaurant, color: AppTheme.rojo, size: 32),
                  ),
                  destinations: items
                      .map((i) => NavigationRailDestination(icon: Icon(i.icon), label: Text(i.label)))
                      .toList(),
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        color: AppTheme.crema,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        child: Text('$establecimiento · ${AppFormat.hoy()}',
                            style: const TextStyle(fontSize: 12, color: AppTheme.gris)),
                      ),
                      Expanded(child: _content(_actual)),
                    ],
                  ),
                ),
              ],
            ),
          );
        }
        return Scaffold(
          drawer: drawer,
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo),
                Text(establecimiento, style: const TextStyle(fontSize: 11, color: Colors.white70)),
              ],
            ),
            actions: [
              IconButton(tooltip: 'Cambiar de rol', onPressed: state.logout, icon: const Icon(Icons.logout)),
            ],
          ),
          body: _content(_actual),
        );
      },
    );
  }
}
