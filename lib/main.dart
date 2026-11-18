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
        scaffoldBackgroundColor: const Color(0xFF0D1117),
        primaryColor: const Color(0xFF2F81F7),
        cardColor: const Color(0xFF161B22),
        dialogBackgroundColor: const Color(0xFF161B22),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF2F81F7),
          secondary: Color(0xFF3FB950),
          surface: Color(0xFF161B22),
          error: Color(0xFFF85149),
        ),
        useMaterial3: true,
      ),
      home: const MainNavigationScreen(),
    );
  }
}

// ============================================================================
// GESTOR DE BASE DE DATOS SQLITE (erp_juan_v2.db)
// ============================================================================
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
    // Asegurar columnas nuevas si viene de v1 o v2 sin borrar datos
    try {
      await db.execute("ALTER TABLE productos ADD COLUMN proveedor TEXT DEFAULT ''");
    } catch (_) {}
    try {
      await db.execute("ALTER TABLE movimientos ADD COLUMN cantidad INTEGER NOT NULL DEFAULT 1");
    } catch (_) {}
    try {
      await db.execute("ALTER TABLE movimientos ADD COLUMN precio_unitario REAL NOT NULL DEFAULT 0.0");
    } catch (_) {}
    try {
      await db.execute("ALTER TABLE movimientos ADD COLUMN estado_cobro TEXT DEFAULT 'Pagado'");
    } catch (_) {}
  }

  // Retroalimentar cliente automáticamente si no existe
  Future<void> asegurarCliente(String nombre, String tipoTarifa) async {
    final limpio = nombre.trim();
    if (limpio.isEmpty) return;
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

// ============================================================================
// PANTALLA PRINCIPAL CON NAVEGACIÓN INFERIOR
// ============================================================================
class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  int _refreshKey = 0;

  void _triggerRefresh() {
    setState(() {
      _refreshKey++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardTab(key: ValueKey('dash_$_refreshKey'), onRefresh: _triggerRefresh),
      CobrosTab(key: ValueKey('cobros_$_refreshKey'), onRefresh: _triggerRefresh),
      StockTab(key: ValueKey('stock_$_refreshKey'), onRefresh: _triggerRefresh),
      KardexTab(key: ValueKey('kardex_$_refreshKey'), onRefresh: _triggerRefresh),
      ClientesTab(key: ValueKey('clientes_$_refreshKey'), onRefresh: _triggerRefresh),
    ];

    return Scaffold(
      body: SafeArea(child: pages[_currentIndex]),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (idx) => setState(() => _currentIndex = idx),
        type: BottomNavigationBarType.fixed,
        backgroundColor: const Color(0xFF161B22),
        selectedItemColor: const Color(0xFF2F81F7),
        unselectedItemColor: Colors.grey,
        selectedFontSize: 11,
        unselectedFontSize: 11,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: 'Inicio'),
          BottomNavigationBarItem(icon: Icon(Icons.schedule_rounded), label: 'Cobros'),
          BottomNavigationBarItem(icon: Icon(Icons.hub_rounded), label: 'Stock'),
          BottomNavigationBarItem(icon: Icon(Icons.receipt_long_rounded), label: 'Kardex'),
          BottomNavigationBarItem(icon: Icon(Icons.people_alt_rounded), label: 'Clientes'),
        ],
      ),
    );
  }
}

// ============================================================================
// 1. PESTAÑA INICIO (DASHBOARD + ACCESOS RÁPIDOS VENTA / COMPRA)
// ============================================================================
class DashboardTab extends StatefulWidget {
  final VoidCallback onRefresh;
  const DashboardTab({super.key, required this.onRefresh});

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  double totalVentas = 0;
  double totalCompras = 0;
  double pendienteCobro = 0;
  double beneficioNeto = 0;

  @override
  void initState() {
    super.initState();
    _cargarMetricas();
  }

  Future<void> _cargarMetricas() async {
    final db = await DatabaseHelper.instance.database;
    final movs = await db.query('movimientos');
    double v = 0, c = 0, pCobro = 0;

    for (var m in movs) {
      final tipo = (m['tipo'] ?? '').toString().toUpperCase();
      final imp = (m['importe'] as num?)?.toDouble() ?? 0.0;
      final estado = (m['estado_cobro'] ?? 'Pagado').toString();

      
