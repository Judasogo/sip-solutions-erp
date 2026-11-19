import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const ERPJuanApp());
}

class ERPJuanApp extends StatelessWidget {
  const ERPJuanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ERP Juan',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0B101B),
        primaryColor: const Color(0xFF2F81F7),
        cardColor: const Color(0xFF131B2E),
        dialogBackgroundColor: const Color(0xFF131B2E),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF2F81F7),
          secondary: Color(0xFF10B981),
          surface: Color(0xFF131B2E),
          error: Color(0xFFEF4444),
        ),
        useMaterial3: true,
      ),
      home: const DashboardOverviewScreen(),
    );
  }
}

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('erp_juan_v2.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, filePath);
    return await openDatabase(
      path,
      version: 3,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS productos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL,
        stock INTEGER NOT NULL DEFAULT 0,
        costo_compra REAL NOT NULL DEFAULT 0.0,
        precio_pvp REAL NOT NULL DEFAULT 0.0,
        precio_colaborador REAL NOT NULL DEFAULT 0.0,
        proveedor TEXT DEFAULT ''
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS clientes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL UNIQUE,
        tipo TEXT NOT NULL DEFAULT 'Cliente Final',
        telefono TEXT DEFAULT ''
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS movimientos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        tipo TEXT NOT NULL,
        producto_id INTEGER,
        producto_nombre TEXT NOT NULL,
        cliente_proveedor TEXT NOT NULL,
        tarifa TEXT DEFAULT 'PVP',
        cantidad INTEGER NOT NULL DEFAULT 1,
        precio_unitario REAL NOT NULL DEFAULT 0.0,
        importe REAL NOT NULL DEFAULT 0.0,
        metodo_pago TEXT DEFAULT 'Contado / Efectivo',
        estado_cobro TEXT DEFAULT 'Pagado',
        fecha TEXT NOT NULL
      )
    ''');
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    await _createDB(db, newVersion);
    try { await db.execute("ALTER TABLE productos ADD COLUMN proveedor TEXT DEFAULT ''"); } catch (_) {}
    try { await db.execute("ALTER TABLE movimientos ADD COLUMN cantidad INTEGER NOT NULL DEFAULT 1"); } catch (_) {}
    try { await db.execute("ALTER TABLE movimientos ADD COLUMN precio_unitario REAL NOT NULL DEFAULT 0.0"); } catch (_) {}
    try { await db.execute("ALTER TABLE movimientos ADD COLUMN estado_cobro TEXT DEFAULT 'Pagado'"); } catch (_) {}
  }

  Future<void> asegurarCliente(String nombre, String tipoTarifa) async {
    final limpio = nombre.trim();
    if (limpio.isEmpty || limpio == 'Cliente General') return;
    final db = await database;
    final existe = await db.query(
      'clientes',
      where: 'LOWER(nombre) = ?',
      whereArgs: [limpio.toLowerCase()],
    );
    if (existe.isEmpty) {
      await db.insert('clientes', {
        'nombre': limpio,
        'tipo': tipoTarifa.contains('Colab') ? 'Colaborador' : 'Cliente Final',
        'telefono': '',
      });
    }
  }
}

class DashboardOverviewScreen extends StatefulWidget {
  const DashboardOverviewScreen({super.key});

  @override
  State<DashboardOverviewScreen> createState() => _DashboardOverviewScreenState();
}

class _DashboardOverviewScreenState extends State<DashboardOverviewScreen> {
  double ventasTotales = 0.0;
  double beneficioNeto = 0.0;
  double porCobrar = 0.0;
  double comprasCosto = 0.0;

  String filtroActivo = 'TODOS';
  List movimientos = [];

  final costoSimCtrl = TextEditingController(text: '37');
  final margenSimCtrl = TextEditingController(text: '143.24');
  double precioRecomendado = 90.00;
  double beneficioUnitario = 53.00;

  @override
  void initState() {
    super.initState();
    _recalcularSimulador();
    _cargarTodo();
  }

  void _recalcularSimulador() {
    final costo = double.tryParse(costoSimCtrl.text.replaceAll(',', '.')) ?? 0.0;
    final margen = double.tryParse(margenSimCtrl.text.replaceAll(',', '.')) ?? 0.0;
    setState(() {
      precioRecomendado = costo * (1 + (margen / 100));
      beneficioUnitario = precioRecomendado - costo;
    });
  }

  Future<void> _cargarTodo() async {
    final db = await DatabaseHelper.instance.database;
    final todosMovs = await db.query('movimientos', orderBy: 'id DESC');

    double v = 0.0;
    double c = 0.0;
    double pCobro = 0.0;

    for (var m in todosMovs) {
      final tipo = (m['tipo'] ?? '').toString().toUpperCase();
      final imp = (m['importe'] as num?)?.toDouble() ?? 0.0;
      final estado = (m['estado_cobro'] ?? 'Pagado').toString();

      if (tipo == 'VENTA') {
        v += imp;
        if (estado == 'Pendiente') pCobro += imp;
      } else if (tipo == 'COMPRA') {
        c += imp;
      } else if (tipo == 'COBRO') {
        if (estado == 'Pendiente') {
          pCobro += imp;
        } else {
          v += imp;
        }
      }
    }

    List filtrados = [];
    if (filtroActivo == 'TODOS') {
      filtrados = todosMovs;
    } else if (filtroActivo == 'VENTA') {
      filtrados = todosMovs.where((m) {
        final t = (m['tipo'] ?? '').toString().toUpperCase();
        return t == 'VENTA' || t == 'COBRO';
      }).toList();
    } else if (filtroActivo == 'COMPRA') {
      filtrados = todosMovs.where((m) => (m['tipo'] ?? '').toString().toUpperCase() == 'COMPRA').toList();
    } else if (filtroActivo == 'COBRO') {
      filtrados = todosMovs.where((m) {
        final t = (m['tipo'] ?? '').toString().toUpperCase();
        final e = (m['estado_cobro'] ?? '').toString();
        return t == 'COBRO' || e == 'Pendiente';
      }).toList();
    } else if (filtroActivo == 'PROVEEDOR') {
      filtrados = todosMovs.where((m) => (m['tipo'] ?? '').toString().toUpperCase() == 'COMPRA').toList();
    }

    if (mounted) {
      setState(() {
        ventasTotales = v;
        comprasCosto = c;
        porCobrar = pCobro;
        beneficioNeto = v - c;
        movimientos = filtrados;
      });
    }
  }

  void _abrirMenuModulos() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF131B2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Módulos del Sistema', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.inventory_2_rounded, color: Color(0xFF2F81F7)),
              title: const Text('Inventario & Stock', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              subtitle: const Text('Gestionar productos, precios PVP/Colaborador y proveedores', style: TextStyle(color: Colors.grey, fontSize: 12)),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(context, MaterialPageRoute(builder: (_) => StockScreen(onChanged: _cargarTodo)));
              },
            ),
            ListTile(
              leading: const Icon(Icons.people_alt_rounded, color: Color(0xFF10B981)),
              title: const Text('Clientes & Colaboradores', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              subtitle: const Text('Base de datos de clientes y tarifas especiales', style: TextStyle(color: Colors.grey, fontSize: 12)),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(context, MaterialPageRoute(builder: (_) => ClientesScreen(onChanged: _cargarTodo)));
              },
            ),
            ListTile(
              leading: const Icon(Icons.pending_actions_rounded, color: Colors.orangeAccent),
              title: const Text('Cuentas por Cobrar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              subtitle: const Text('Ver pagos pendientes y liquidar cobros', style: TextStyle(color: Colors.grey, fontSize: 12)),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(context, MaterialPageRoute(builder: (_) => CobrosScreen(onChanged: _cargarTodo)));
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtros = ['TODOS', 'VENTA', 'COMPRA', 'COBRO', 'PROVEEDOR'];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B101B),
        elevation: 0,
        title: const Text('Dashboard Overview', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF2F81F7)),
            onPressed: _cargarTodo,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF2F81F7),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onPressed: _abrirMenuModulos,
        child: const Icon(Icons.menu_rounded, color: Colors.white, size: 28),
      ),
      body: RefreshIndicator(
        onRefresh: _cargarTodo,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
          children: [
            // Cabecera ERP Juan
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF131B2E),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2F81F7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: const Text('J', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('ERP Juan', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white)),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Container(width: 7, height: 7, decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle)),
                            const SizedBox(width: 6),
                            Text('Cuentas & Alertas Activas', style: TextStyle(fontSize: 12, color: Colors.grey[400])),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1D2842),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF2F81F7).withOpacity(0.4)),
                    ),
                    child: const Text('Por Juan', style: TextStyle(fontSize: 12, color: Color(0xFF60A5FA), fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Botones + Nueva Venta y + Nueva Compra lado a lado
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
                    label: const Text('+ Nueva Venta', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    onPressed: () => mostrarDialogoVenta(context, _cargarTodo),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2F81F7),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.shopping_cart_outlined, size: 20),
                    label: const Text('+ Nueva Compra', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    onPressed: () => mostrarDialogoCompra(context, _cargarTodo),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Grid 2x2 de KPIs
            Row(
              children: [
                Expanded(
                  child: _buildKpiBox(
                    titulo: 'VENTAS TOTALES',
                    valor: '${ventasTotales.toStringAsFixed(2)} €',
                    subtitulo: 'Ingresos registrados',
                    subColor: const Color(0xFF60A5FA),
                    icono: Icons.trending_up_rounded,
                    iconColor: const Color(0xFF60A5FA),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildKpiBox(
                    titulo: 'BENEFICIO NETO',
                    valor: '${beneficioNeto.toStringAsFixed(2)} €',
                    subtitulo: 'Ventas - Compras',
                    subColor: const Color(0xFF10B981),
                    icono: Icons.account_balance_wallet_outlined,
                    iconColor: const Color(0xFF10B981),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CobrosScreen(onChanged: _cargarTodo))),
                    child: _buildKpiBox(
                      titulo: 'POR COBRAR',
                      valor: '${porCobrar.toStringAsFixed(2)} €',
                      subtitulo: 'Cuentas pendientes',
                      subColor: const Color(0xFFEF4444),
                      icono: Icons.assignment_late_outlined,
                      iconColor: const Color(0xFFEF4444),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => StockScreen(onChanged: _cargarTodo))),
                    child: _buildKpiBox(
                      titulo: 'COMPRAS / COSTO',
                      valor: '${comprasCosto.toStringAsFixed(2)} €',
                      subtitulo: 'Inversión stock',
                      subColor: const Color(0xFFF59E0B),
                      icono: Icons.inventory_2_outlined,
                      iconColor: const Color(0xFFF59E0B),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Calculadora & Simulador en Vivo
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF131B2E),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.calculate_outlined, color: Color(0xFF60A5FA), size: 20),
                      SizedBox(width: 8),
                      Text('Calculadora & Simulador en Vivo', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('Simula precios para Cliente Final o Colaborador.', style: TextStyle(fontSize: 12, color: Colors.grey[400])),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: costoSimCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'Costo Unitario (€)',
                            filled: true,
                            fillColor: const Color(0xFF1A243B),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                          ),
                          onChanged: (_) => _recalcularSimulador(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: margenSimCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'Margen Deseado (%)',
                            filled: true,
                            fillColor: const Color(0xFF1A243B),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                          ),
                          onChanged: (_) => _recalcularSimulador(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A243B),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('PRECIO VENTA RECOMENDADO', style: TextStyle(fontSize: 10, color: Colors.grey[400], fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            Text('${precioRecomendado.toStringAsFixed(2)} €', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF60A5FA))),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('BENEFICIO UNITARIO', style: TextStyle(fontSize: 10, color: Colors.grey[400], fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            Text('${beneficioUnitario.toStringAsFixed(2)} €', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Módulos & Movimientos
            const Text('Módulos & Movimientos', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 12),

            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: filtros.map((f) {
                  final sel = filtroActivo == f;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      avatar: sel ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
                      label: Text(f),
                      selected: sel,
                      showCheckmark: false,
                      selectedColor: const Color(0xFF2F81F7),
                      backgroundColor: const Color(0xFF131B2E),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(color: sel ? const Color(0xFF2F81F7) : Colors.white12),
                      ),
                      labelStyle: TextStyle(
                        color: sel ? Colors.white : Colors.grey[300],
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                      onSelected: (_) {
                        setState(() => filtroActivo = f);
                        _cargarTodo();
                      },
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 12),

            if (movimientos.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF131B2E),
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: const Text('No hay movimientos registrados en este filtro.', style: TextStyle(color: Colors.grey)),
              )
            else
              ...movimientos.map((m) {
                final tipo = (m['tipo'] ?? '').toString().toUpperCase();
                final esCompra = tipo == 'COMPRA';
                final esPendiente = (m['estado_cobro'] ?? '') == 'Pendiente';
                final cant = m['cantidad'] ?? 1;

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF131B2E),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${m['cliente_proveedor']} (${m['producto_nombre']} x$cant)',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$tipo • ${m['tarifa']} (${m['metodo_pago']}) • ${m['fecha']}',
                              style: TextStyle(color: Colors.grey[400], fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${esCompra ? '-' : '+'}${(m['importe'] as num).toStringAsFixed(2)} €',
                            style: TextStyle(
                              color: esCompra
                                  ? const Color(0xFFEF4444)
                                  : (esPendiente ? Colors.orangeAccent : const Color(0xFF10B981)),
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          if (esPendiente)
                            GestureDetector(
                              onTap: () async {
                                final db = await DatabaseHelper.instance.database;
                                await db.update(
                                  'movimientos',
                                  {'tipo': 'VENTA', 'estado_cobro': 'Pagado'},
                                  where: 'id = ?',
                                  whereArgs: [m['id']],
                                );
                                _cargarTodo();
                              },
                              child: const Padding(
                                padding: EdgeInsets.only(top: 4),
                                child: Text('Marcar cobrado', style: TextStyle(color: Color(0xFF60A5FA), fontSize: 11, fontWeight: FontWeight.bold)),
                              ),
                            ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.grey, size: 20),
                        onPressed: () async {
                          final db = await DatabaseHelper.instance.database;
                          await db.delete('movimientos', where: 'id = ?', whereArgs: [m['id']]);
                          _cargarTodo();
                        },
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiBox({
    required String titulo,
    required String valor,
    required String subtitulo,
    required Color subColor,
    required IconData icono,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF131B2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(titulo, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey[400])),
              Icon(icono, size: 18, color: iconColor),
            ],
          ),
          const SizedBox(height: 10),
          Text(valor, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 6),
          Text(subtitulo, style: TextStyle(fontSize: 12, color: subColor, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class StockScreen extends StatefulWidget {
  final VoidCallback onChanged;
  const StockScreen({super.key, required this.onChanged});

  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> {
  List productos = [];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final db = await DatabaseHelper.instance.database;
    final res = await db.query('productos', orderBy: 'nombre ASC');
    if (mounted) setState(() => productos = res);
  }

  void _dialogoProducto([Map? prod]) {
    final nombreCtrl = TextEditingController(text: prod?['nombre'] ?? '');
    final stockCtrl = TextEditingController(text: (prod?['stock'] ?? 0).toString());
    final costoCtrl = TextEditingController(text: (prod?['costo_compra'] ?? '').toString());
    final pvpCtrl = TextEditingController(text: (prod?['precio_pvp'] ?? '').toString());
    final colabCtrl = TextEditingController(text: (prod?['precio_colaborador'] ?? '').toString());
    final provCtrl = TextEditingController(text: prod?['proveedor'] ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(prod == null ? 'Nuevo Producto' : 'Editar Producto'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nombreCtrl, decoration: const InputDecoration(labelText: 'Nombre del Producto')),
              const SizedBox(height: 8),
              TextField(controller: provCtrl, decoration: const InputDecoration(labelText: 'Proveedor')),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: TextField(controller: stockCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Stock Actual'))),
                  const SizedBox(width: 10),
                  Expanded(child: TextField(controller: costoCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Costo Compra (€)'))),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: TextField(controller: pvpCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Precio PVP (€)'))),
                  const SizedBox(width: 10),
                  Expanded(child: TextField(controller: colabCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Precio Colab (€)'))),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              final nombre = nombreCtrl.text.trim();
              if (nombre.isEmpty) return;
              final data = {
                'nombre': nombre,
                'proveedor': provCtrl.text.trim(),
                'stock': int.tryParse(stockCtrl.text) ?? 0,
                'costo_compra': double.tryParse(costoCtrl.text.replaceAll(',', '.')) ?? 0.0,
                'precio_pvp': double.tryParse(pvpCtrl.text.replaceAll(',', '.')) ?? 0.0,
                'precio_colaborador': double.tryParse(colabCtrl.text.replaceAll(',', '.')) ?? 0.0,
              };
              final db = await DatabaseHelper.instance.database;
              if (prod == null) {
                await db.insert('productos', data);
              } else {
                await db.update('productos', data, where: 'id = ?', whereArgs: [prod['id']]);
              }
              if (ctx.mounted) Navigator.pop(ctx);
              _cargar();
              widget.onChanged();
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Inventario & Stock'), backgroundColor: const Color(0xFF0B101B)),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF2F81F7),
        onPressed: () => _dialogoProducto(),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: productos.isEmpty
          ? const Center(child: Text('No hay productos registrados.', style: TextStyle(color: Colors.grey)))
          : ListView.builder(
              padding: const EdgeInsets.all(14),
              itemCount: productos.length,
              itemBuilder: (context, i) {
                final pr = productos[i];
                return Card(
                  color: const Color(0xFF131B2E),
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    onTap: () => _dialogoProducto(pr),
                    title: Text(pr['nombre'], style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                    subtitle: Text('PVP: ${pr['precio_pvp']}€ | Colab: ${pr['precio_colaborador']}€ | Prov: ${pr['proveedor']}'),
                    trailing: Text('${pr['stock']} uds', style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold)),
                  ),
                );
              },
            ),
    );
  }
}

class ClientesScreen extends StatefulWidget {
  final VoidCallback onChanged;
  const ClientesScreen({super.key, required this.onChanged});

  @override
  State<ClientesScreen> createState() => _ClientesScreenState();
}

class _ClientesScreenState extends State<ClientesScreen> {
  List clientes = [];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final db = await DatabaseHelper.instance.database;
    final res = await db.query('clientes', orderBy: 'nombre ASC');
    if (mounted) setState(() => clientes = res);
  }

  void _nuevoCliente() {
    final nombreCtrl = TextEditingController();
    final telCtrl = TextEditingController();
    String tipo = 'Cliente Final';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDlg) => AlertDialog(
          title: const Text('Nuevo Cliente / Colaborador'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nombreCtrl, decoration: const InputDecoration(labelText: 'Nombre')),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: tipo,
                decoration: const InputDecoration(labelText: 'Tipo'),
                items: const [
                  DropdownMenuItem(value: 'Cliente Final', child: Text('Cliente Final (PVP)')),
                  DropdownMenuItem(value: 'Colaborador', child: Text('Colaborador')),
                ],
                onChanged: (v) => setStateDlg(() => tipo = v!),
              ),
              const SizedBox(height: 10),
              TextField(controller: telCtrl, decoration: const InputDecoration(labelText: 'Teléfono (opcional)')),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () async {
                if (nombreCtrl.text.trim().isEmpty) return;
                final db = await DatabaseHelper.instance.database;
                await db.insert('clientes', {
                  'nombre': nombreCtrl.text.trim(),
                  'tipo': tipo,
                  'telefono': telCtrl.text.trim(),
                }, conflictAlgorithm: ConflictAlgorithm.replace);
                if (ctx.mounted) Navigator.pop(ctx);
                _cargar();
                widget.onChanged();
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Clientes & Colaboradores'), backgroundColor: const Color(0xFF0B101B)),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF2F81F7),
        onPressed: _nuevoCliente,
        child: const Icon(Icons.person_add, color: Colors.white),
      ),
      body: clientes.isEmpty
          ? const Center(child: Text('Aún no hay clientes guardados.', style: TextStyle(color: Colors.grey)))
          : ListView.builder(
              padding: const EdgeInsets.all(14),
              itemCount: clientes.length,
              itemBuilder: (context, i) {
                final c = clientes[i];
                return Card(
                  color: const Color(0xFF131B2E),
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    title: Text(c['nombre'], style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                    subtitle: Text('${c['tipo']} ${c['telefono']}'),
                  ),
                );
              },
            ),
    );
  }
}

class CobrosScreen extends StatefulWidget {
  final VoidCallback onChanged;
  const CobrosScreen({super.key, required this.onChanged});

  @override
  State<CobrosScreen> createState() => _CobrosScreenState();
}

class _CobrosScreenState extends State<CobrosScreen> {
  List cobros = [];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final db = await DatabaseHelper.instance.database;
    final res = await db.query(
      'movimientos',
      where: "tipo = 'COBRO' OR estado_cobro = 'Pendiente'",
      orderBy: 'id DESC',
    );
    if (mounted) setState(() => cobros = res);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cuentas por Cobrar'), backgroundColor: const Color(0xFF0B101B)),
      body: cobros.isEmpty
          ? const Center(child: Text('No hay cobros pendientes.', style: TextStyle(color: Colors.grey)))
          : ListView.builder(
              padding: const EdgeInsets.all(14),
              itemCount: cobros.length,
              itemBuilder: (context, i) {
                final c = cobros[i];
                final pend = (c['estado_cobro'] ?? '') == 'Pendiente';
                return Card(
                  color: const Color(0xFF131B2E),
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    title: Text('${c['cliente_proveedor']} (${c['producto_nombre']} x${c['cantidad'] ?? 1})'),
                    subtitle: Text('${c['fecha']} • ${c['metodo_pago']}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('${(c['importe'] as num).toStringAsFixed(2)} €', style: TextStyle(color: pend ? Colors.orangeAccent : const Color(0xFF10B981), fontWeight: FontWeight.bold)),
                        if (pend)
                          IconButton(
                            icon: const Icon(Icons.check_circle, color: Color(0xFF10B981)),
                            onPressed: () async {
                              final db = await DatabaseHelper.instance.database;
                              await db.update('movimientos', {'tipo': 'VENTA', 'estado_cobro': 'Pagado'}, where: 'id = ?', whereArgs: [c['id']]);
                              _cargar();
                              widget.onChanged();
                            },
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

Future<void> mostrarDialogoVenta(BuildContext context, VoidCallback onSaved) async {
  final db = await DatabaseHelper.instance.database;
  final productos = await db.query('productos', orderBy: 'nombre ASC');
  final clientes = await db.query('clientes', orderBy: 'nombre ASC');

  if (productos.isEmpty) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Primero crea al menos un producto en Inventario & Stock (menú inferior derecho).')));
    }
    return;
  }

  Map prodSel = productos.first;
  String tarifaSel = 'Cliente Final (PVP)';
  String metodoPago = 'Contado / Efectivo';
  String estadoCobro = 'Pagado';

  final cantidadCtrl = TextEditingController(text: '1');
  final clienteCtrl = TextEditingController();
  final totalCtrl = TextEditingController(text: ((prodSel['precio_pvp'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2));

  void recalcularTotal() {
    final cant = int.tryParse(cantidadCtrl.text) ?? 1;
    final unit = tarifaSel.contains('Colab')
        ? ((prodSel['precio_colaborador'] as num?)?.toDouble() ?? 0.0)
        : ((prodSel['precio_pvp'] as num?)?.toDouble() ?? 0.0);
    totalCtrl.text = (cant * unit).toStringAsFixed(2);
  }

  if (!context.mounted) return;

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setStateDlg) => AlertDialog(
        title: const Text('Registrar Nueva Venta'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                value: prodSel['id'] as int,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Producto'),
                items: productos.map((pr) => DropdownMenuItem<int>(
                  value: pr['id'] as int,
                  child: Text('${pr['nombre']} (PVP ${pr['precio_pvp']}€ / Col ${pr['precio_colaborador']}€)'),
                )).toList(),
                onChanged: (id) => setStateDlg(() {
                  prodSel = productos.firstWhere((e) => e['id'] == id);
                  recalcularTotal();
                }),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: clienteCtrl,
                decoration: InputDecoration(
                  labelText: 'Cliente / Colaborador',
                  hintText: 'Escribe nombre o elige de la lista',
                  suffixIcon: clientes.isEmpty
                      ? null
                      : PopupMenuButton<String>(
                          icon: const Icon(Icons.arrow_drop_down),
                          onSelected: (nombreElegido) {
                            setStateDlg(() {
                              clienteCtrl.text = nombreElegido;
                              final encontrado = clientes.firstWhere((c) => c['nombre'] == nombreElegido, orElse: () => {});
                              tarifaSel = encontrado['tipo'] == 'Colaborador' ? 'Colaborador' : 'Cliente Final (PVP)';
                              recalcularTotal();
                            });
                          },
                          itemBuilder: (BuildContext context) {
                            return clientes.map((c) {
                              final nom = c['nombre'].toString();
                              final tip = c['tipo'].toString();
                              return PopupMenuItem<String>(value: nom, child: Text('$nom ($tip)'));
                            }).toList();
                          },
                        ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  SizedBox(
                    width: 85,
                    child: TextField(
                      controller: cantidadCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Cantidad'),
                      onChanged: (_) => setStateDlg(() => recalcularTotal()),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: tarifaSel,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Tarifa'),
                      items: const [
                        DropdownMenuItem(value: 'Cliente Final (PVP)', child: Text('Cliente Final (PVP)')),
                        DropdownMenuItem(value: 'Colaborador', child: Text('Colaborador')),
                      ],
                      onChanged: (val) => setStateDlg(() {
                        tarifaSel = val!;
                        recalcularTotal();
                      }),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: totalCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Importe Total (€)'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: metodoPago,
                decoration: const InputDecoration(labelText: 'Método de Pago'),
                items: const [
                  DropdownMenuItem(value: 'Contado / Efectivo', child: Text('Contado / Efectivo')),
                  DropdownMenuItem(value: 'Bizum', child: Text('Bizum')),
                  DropdownMenuItem(value: 'Transferencia', child: Text('Transferencia')),
                  DropdownMenuItem(value: 'Crédito / Fiado', child: Text('Crédito / Pendiente')),
                ],
                onChanged: (val) => setStateDlg(() {
                  metodoPago = val!;
                  estadoCobro = metodoPago.contains('Crédito') ? 'Pendiente' : 'Pagado';
                }),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: estadoCobro,
                decoration: const InputDecoration(labelText: 'Estado del Cobro'),
                items: const [
                  DropdownMenuItem(value: 'Pagado', child: Text('Cobrado / Pagado')),
                  DropdownMenuItem(value: 'Pendiente', child: Text('Pendiente de Cobro')),
                ],
                onChanged: (val) => setStateDlg(() => estadoCobro = val!),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              final clienteNombre = clienteCtrl.text.trim().isEmpty ? 'Cliente General' : clienteCtrl.text.trim();
              final cant = int.tryParse(cantidadCtrl.text) ?? 1;
              final total = double.tryParse(totalCtrl.text.replaceAll(',', '.')) ?? 0.0;
              final unit = cant > 0 ? total / cant : total;
              final fechaHoy = DateTime.now().toIso8601String().split('T')[0];

              await DatabaseHelper.instance.asegurarCliente(clienteNombre, tarifaSel);

              final stockActual = (prodSel['stock'] as int?) ?? 0;
              final nuevoStock = (stockActual - cant) < 0 ? 0 : (stockActual - cant);
              await db.update('productos', {'stock': nuevoStock}, where: 'id = ?', whereArgs: [prodSel['id']]);

              await db.insert('movimientos', {
                'tipo': 'VENTA',
                'producto_id': prodSel['id'],
                'producto_nombre': prodSel['nombre'],
                'cliente_proveedor': clienteNombre,
                'tarifa': tarifaSel.contains('Colab') ? 'Colaborador' : 'PVP',
                'cantidad': cant,
                'precio_unitario': unit,
                'importe': total,
                'metodo_pago': metodoPago,
                'estado_cobro': estadoCobro,
                'fecha': fechaHoy,
              });

              if (ctx.mounted) Navigator.pop(ctx);
              onSaved();
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    ),
  );
}

Future<void> mostrarDialogoCompra(BuildContext context, VoidCallback onSaved) async {
  final db = await DatabaseHelper.instance.database;
  final productos = await db.query('productos', orderBy: 'nombre ASC');

  if (productos.isEmpty) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Primero crea el producto en Inventario & Stock (menú inferior derecho).')));
    }
    return;
  }

  Map prodSel = productos.first;
  final provCtrl = TextEditingController(text: prodSel['proveedor']?.toString() ?? '');
  final cantidadCtrl = TextEditingController(text: '1');
  final costoUnitCtrl = TextEditingController(text: ((prodSel['costo_compra'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2));
  final totalCtrl = TextEditingController(text: costoUnitCtrl.text);

  void recalcularCompra() {
    final cant = int.tryParse(cantidadCtrl.text) ?? 1;
    final unit = double.tryParse(costoUnitCtrl.text.replaceAll(',', '.')) ?? 0.0;
    totalCtrl.text = (cant * unit).toStringAsFixed(2);
  }

  if (!context.mounted) return;

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setStateDlg) => AlertDialog(
        title: const Text('Registrar Nueva Compra'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                value: prodSel['id'] as int,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Producto'),
                items: productos.map((pr) => DropdownMenuItem<int>(
                  value: pr['id'] as int,
                  child: Text('${pr['nombre']} (Stock: ${pr['stock']})'),
                )).toList(),
                onChanged: (id) => setStateDlg(() {
                  prodSel = productos.firstWhere((e) => e['id'] == id);
                  provCtrl.text = prodSel['proveedor']?.toString() ?? '';
                  costoUnitCtrl.text = ((prodSel['costo_compra'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2);
                  recalcularCompra();
                }),
              ),
              const SizedBox(height: 12),
              TextField(controller: provCtrl, decoration: const InputDecoration(labelText: 'Proveedor')),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: cantidadCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Cantidad'),
                      onChanged: (_) => setStateDlg(() => recalcularCompra()),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: costoUnitCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Costo Unit. (€)'),
                      onChanged: (_) => setStateDlg(() => recalcularCompra()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: totalCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Total Compra (€)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              final cant = int.tryParse(cantidadCtrl.text) ?? 1;
              final unit = double.tryParse(costoUnitCtrl.text.replaceAll(',', '.')) ?? 0.0;
              final total = double.tryParse(totalCtrl.text.replaceAll(',', '.')) ?? (cant * unit);
              final prov = provCtrl.text.trim().isEmpty ? 'Proveedor General' : provCtrl.text.trim();
              final fechaHoy = DateTime.now().toIso8601String().split('T')[0];

              final stockActual = (prodSel['stock'] as int?) ?? 0;
              await db.update(
                'productos',
                {'stock': stockActual + cant, 'costo_compra': unit, 'proveedor': prov},
                where: 'id = ?',
                whereArgs: [prodSel['id']],
              );

              await db.insert('movimientos', {
                'tipo': 'COMPRA',
                'producto_id': prodSel['id'],
                'producto_nombre': prodSel['nombre'],
                'cliente_proveedor': prov,
                'tarifa': 'Costo Proveedor',
                'cantidad': cant,
                'precio_unitario': unit,
                'importe': total,
                'metodo_pago': 'Contado / Transferencia',
                'estado_cobro': 'Pagado',
                'fecha': fechaHoy,
              });

              if (ctx.mounted) Navigator.pop(ctx);
              onSaved();
            },
            child: const Text('Guardar Compra'),
          ),
        ],
      ),
    ),
  );
}