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

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  int _refreshKey = 0;

  void _triggerRefresh() => setState(() => _refreshKey++);

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

class DashboardTab extends StatefulWidget {
  final VoidCallback onRefresh;
  const DashboardTab({super.key, required this.onRefresh});

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  double totalVentas = 0, totalCompras = 0, pendienteCobro = 0, beneficioNeto = 0;

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

    if (mounted) {
      setState(() {
        totalVentas = v;
        totalCompras = c;
        pendienteCobro = pCobro;
        beneficioNeto = v - c;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('ERP Juan', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 4),
        Text('Panel de Control Comercial', style: TextStyle(fontSize: 13, color: Colors.grey[400])),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(child: _kpiCard('Ventas Totales', '${totalVentas.toStringAsFixed(2)} €', const Color(0xFF3FB950))),
            const SizedBox(width: 12),
            Expanded(child: _kpiCard('Compras / Inversión', '${totalCompras.toStringAsFixed(2)} €', const Color(0xFFF85149))),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _kpiCard('Por Cobrar', '${pendienteCobro.toStringAsFixed(2)} €', Colors.orangeAccent)),
            const SizedBox(width: 12),
            Expanded(child: _kpiCard('Balance Neto', '${beneficioNeto.toStringAsFixed(2)} €', const Color(0xFF2F81F7))),
          ],
        ),
        const SizedBox(height: 24),
        const Text('Operaciones Rápidas', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF238636),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          icon: const Icon(Icons.add_shopping_cart_rounded),
          label: const Text('Registrar Nueva Venta', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          onPressed: () => mostrarDialogoVenta(context, () {
            _cargarMetricas();
            widget.onRefresh();
          }),
        ),
        const SizedBox(height: 10),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1F6FEB),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          icon: const Icon(Icons.inventory_rounded),
          label: const Text('Registrar Compra a Proveedor', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          onPressed: () => mostrarDialogoCompra(context, () {
            _cargarMetricas();
            widget.onRefresh();
          }),
        ),
      ],
    );
  }

  Widget _kpiCard(String title, String value, Color accent) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 12, color: Colors.grey[400])),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: accent)),
        ],
      ),
    );
  }
}

class CobrosTab extends StatefulWidget {
  final VoidCallback onRefresh;
  const CobrosTab({super.key, required this.onRefresh});

  @override
  State<CobrosTab> createState() => _CobrosTabState();
}

class _CobrosTabState extends State<CobrosTab> {
  List cobros = [];

  @override
  void initState() {
    super.initState();
    _cargarCobros();
  }

  Future<void> _cargarCobros() async {
    final db = await DatabaseHelper.instance.database;
    final res = await db.query(
      'movimientos',
      where: "tipo = 'COBRO' OR estado_cobro = 'Pendiente'",
      orderBy: 'id DESC',
    );
    if (mounted) setState(() => cobros = res);
  }

  Future<void> _marcarComoCobrado(Map item) async {
    final db = await DatabaseHelper.instance.database;
    await db.update(
      'movimientos',
      {'tipo': 'VENTA', 'estado_cobro': 'Pagado'},
      where: 'id = ?',
      whereArgs: [item['id']],
    );
    _cargarCobros();
    widget.onRefresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Cuentas por Cobrar'), backgroundColor: Colors.transparent, elevation: 0),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF2F81F7),
        onPressed: () => mostrarDialogoVenta(context, () {
          _cargarCobros();
          widget.onRefresh();
        }, esDesdeCobros: true),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: cobros.isEmpty
          ? const Center(child: Text('No hay cobros pendientes registrados.', style: TextStyle(color: Colors.grey)))
          : ListView.builder(
              padding: const EdgeInsets.all(14),
              itemCount: cobros.length,
              itemBuilder: (context, i) {
                final c = cobros[i];
                final esPendiente = (c['estado_cobro'] ?? '') == 'Pendiente';
                return Card(
                  color: const Color(0xFF161B22),
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    title: Text(
                      '${c['cliente_proveedor']} (${c['producto_nombre']} x${c['cantidad'] ?? 1})',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    subtitle: Text(
                      '${c['tarifa']} • ${c['metodo_pago']} • ${c['fecha']}',
                      style: TextStyle(color: Colors.grey[400], fontSize: 12),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${(c['importe'] as num).toStringAsFixed(2)} €',
                          style: TextStyle(
                            color: esPendiente ? Colors.orangeAccent : const Color(0xFF3FB950),
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        if (esPendiente)
                          IconButton(
                            icon: const Icon(Icons.check_circle_outline, color: Color(0xFF3FB950)),
                            onPressed: () => _marcarComoCobrado(c),
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

class StockTab extends StatefulWidget {
  final VoidCallback onRefresh;
  const StockTab({super.key, required this.onRefresh});

  @override
  State<StockTab> createState() => _StockTabState();
}

class _StockTabState extends State<StockTab> {
  List productos = [];

  @override
  void initState() {
    super.initState();
    _cargarProductos();
  }

  Future<void> _cargarProductos() async {
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
              TextField(
                controller: provCtrl,
                decoration: const InputDecoration(labelText: 'Proveedor habitual', labelStyle: TextStyle(color: Colors.orangeAccent)),
              ),
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
              _cargarProductos();
              widget.onRefresh();
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
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Inventario / Stock'), backgroundColor: Colors.transparent, elevation: 0),
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
                final p = productos[i];
                return Card(
                  color: const Color(0xFF161B22),
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    onTap: () => _dialogoProducto(p),
                    title: Text(p['nombre'], style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                    subtitle: Text(
                      'PVP: ${p['precio_pvp']}€ | Colab: ${p['precio_colaborador']}€ | Prov: ${p['proveedor'] ?? '-'}',
                      style: TextStyle(color: Colors.grey[400], fontSize: 12),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: (p['stock'] as int) > 0 ? const Color(0xFF238636).withOpacity(0.2) : Colors.red.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${p['stock']} uds',
                        style: TextStyle(
                          color: (p['stock'] as int) > 0 ? const Color(0xFF3FB950) : const Color(0xFFF85149),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class KardexTab extends StatefulWidget {
  final VoidCallback onRefresh;
  const KardexTab({super.key, required this.onRefresh});

  @override
  State<KardexTab> createState() => _KardexTabState();
}

class _KardexTabState extends State<KardexTab> {
  String filtro = 'TODOS';
  List movimientos = [];

  @override
  void initState() {
    super.initState();
    _cargarMovimientos();
  }

  Future<void> _cargarMovimientos() async {
    final db = await DatabaseHelper.instance.database;
    var res = [];
    if (filtro == 'TODOS') {
      res = await db.query('movimientos', orderBy: 'id DESC');
    } else if (filtro == 'VENTA') {
      res = await db.query(
        'movimientos',
        where: "tipo = 'VENTA' OR tipo = 'COBRO'",
        orderBy: 'id DESC',
      );
    } else {
      res = await db.query('movimientos', where: 'tipo = ?', whereArgs: [filtro], orderBy: 'id DESC');
    }
    if (mounted) setState(() => movimientos = res);
  }

  @override
  Widget build(BuildContext context) {
    final filtros = ['TODOS', 'VENTA', 'COMPRA', 'COBRO'];

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Kardex de Movimientos'), backgroundColor: Colors.transparent, elevation: 0),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF2F81F7),
        onPressed: () => mostrarDialogoVenta(context, () {
          _cargarMovimientos();
          widget.onRefresh();
        }),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              children: filtros.map((f) {
                final sel = filtro == f;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(f),
                    selected: sel,
                    selectedColor: const Color(0xFF2F81F7),
                    backgroundColor: const Color(0xFF161B22),
                    labelStyle: TextStyle(color: sel ? Colors.white : Colors.grey[300], fontWeight: FontWeight.bold),
                    onSelected: (_) {
                      setState(() => filtro = f);
                      _cargarMovimientos();
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: movimientos.isEmpty
                ? const Center(child: Text('Sin movimientos en este filtro.', style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                    padding: const EdgeInsets.all(14),
                    itemCount: movimientos.length,
                    itemBuilder: (context, i) {
                      final m = movimientos[i];
                      final tipo = (m['tipo'] ?? '').toString();
                      final esCompra = tipo == 'COMPRA';
                      final cant = m['cantidad'] ?? 1;
                      return Card(
                        color: const Color(0xFF161B22),
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          title: Text(
                            '${m['cliente_proveedor']} (${m['producto_nombre']} x$cant)',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          subtitle: Text(
                            '$tipo • ${m['tarifa']} (${m['metodo_pago']}) • ${m['fecha']}',
                            style: TextStyle(color: Colors.grey[400], fontSize: 12),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${esCompra ? '-' : '+'}${(m['importe'] as num).toStringAsFixed(2)} €',
                                style: TextStyle(
                                  color: esCompra ? const Color(0xFFF85149) : const Color(0xFF3FB950),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.grey, size: 20),
                                onPressed: () async {
                                  final db = await DatabaseHelper.instance.database;
                                  await db.delete('movimientos', where: 'id = ?', whereArgs: [m['id']]);
                                  _cargarMovimientos();
                                  widget.onRefresh();
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class ClientesTab extends StatefulWidget {
  final VoidCallback onRefresh;
  const ClientesTab({super.key, required this.onRefresh});

  @override
  State<ClientesTab> createState() => _ClientesTabState();
}

class _ClientesTabState extends State<ClientesTab> {
  List clientes = [];

  @override
  void initState() {
    super.initState();
    _cargarClientes();
  }

  Future<void> _cargarClientes() async {
    final db = await DatabaseHelper.instance.database;
    final res = await db.query('clientes', orderBy: 'nombre ASC');
    if (mounted) setState(() => clientes = res);
  }

  void _dialogoNuevoCliente() {
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
              TextField(controller: nombreCtrl, decoration: const InputDecoration(labelText: 'Nombre completo')),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: tipo,
                decoration: const InputDecoration(labelText: 'Tipo de Tarifa'),
                items: const [
                  DropdownMenuItem(value: 'Cliente Final', child: Text('Cliente Final (PVP)')),
                  DropdownMenuItem(value: 'Colaborador', child: Text('Colaborador (Tarifa Especial)')),
                ],
                onChanged: (val) => setStateDlg(() => tipo = val!),
              ),
              const SizedBox(height: 10),
              TextField(controller: telCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Teléfono / WhatsApp (opcional)')),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () async {
                final nombre = nombreCtrl.text.trim();
                if (nombre.isEmpty) return;
                final db = await DatabaseHelper.instance.database;
                await db.insert(
                  'clientes',
                  {'nombre': nombre, 'tipo': tipo, 'telefono': telCtrl.text.trim()},
                  conflictAlgorithm: ConflictAlgorithm.replace,
                );
                if (ctx.mounted) Navigator.pop(ctx);
                _cargarClientes();
                widget.onRefresh();
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
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Clientes y Colaboradores'), backgroundColor: Colors.transparent, elevation: 0),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF2F81F7),
        onPressed: _dialogoNuevoCliente,
        child: const Icon(Icons.person_add_alt_1_rounded, color: Colors.white),
      ),
      body: clientes.isEmpty
          ? const Center(child: Text('Aún no hay clientes guardados.', style: TextStyle(color: Colors.grey)))
          : ListView.builder(
              padding: const EdgeInsets.all(14),
              itemCount: clientes.length,
              itemBuilder: (context, i) {
                final cl = clientes[i];
                final esColab = cl['tipo'] == 'Colaborador';
                return Card(
                  color: const Color(0xFF161B22),
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: esColab ? Colors.orange.withOpacity(0.2) : const Color(0xFF2F81F7).withOpacity(0.2),
                      child: Icon(Icons.person, color: esColab ? Colors.orangeAccent : const Color(0xFF2F81F7)),
                    ),
                    title: Text(cl['nombre'], style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                    subtitle: Text(
                      '${cl['tipo']} ${(cl['telefono'] ?? '').toString().isNotEmpty ? "• ${cl['telefono']}" : ""}',
                      style: TextStyle(color: Colors.grey[400], fontSize: 12),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

Future<void> mostrarDialogoVenta(BuildContext context, VoidCallback onSaved, {bool esDesdeCobros = false}) async {
  final db = await DatabaseHelper.instance.database;
  final productos = await db.query('productos', orderBy: 'nombre ASC');
  final clientes = await db.query('clientes', orderBy: 'nombre ASC');

  if (productos.isEmpty) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Primero crea al menos un producto en Stock.')));
    }
    return;
  }

  Map prodSel = productos.first;
  String tarifaSel = 'Cliente Final (PVP)';
  String metodoPago = 'Contado / Efectivo';
  String estadoCobro = esDesdeCobros ? 'Pendiente' : 'Pagado';

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
        title: Text(esDesdeCobros ? 'Nueva Venta / Cuenta por Cobrar' : 'Registrar Nueva Venta'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<int>(
                value: prodSel['id'] as int,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Producto del Stock'),
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
                  hintText: 'Escribe nombre o elige de la flecha',
                  suffixIcon: clientes.isEmpty
                      ? null
                      : PopupMenuButton<String>(
                          icon: const Icon(Icons.arrow_drop_down),
                          onSelected: (nombreElegido) {
                            setStateDlg(() {
                              clienteCtrl.text = nombreElegido;
                              final encontrado = clientes.firstWhere(
                                (c) => c['nombre'] == nombreElegido,
                                orElse: () => {},
                              );
                              if (encontrado['tipo'] == 'Colaborador') {
                                tarifaSel = 'Colaborador';
                              } else {
                                tarifaSel = 'Cliente Final (PVP)';
                              }
                              recalcularTotal();
                            });
                          },
                          itemBuilder: (BuildContext context) {
                            return clientes.map((c) {
                              final nom = c['nombre'].toString();
                              final tip = c['tipo'].toString();
                              return PopupMenuItem<String>(
                                value: nom,
                                child: Text('$nom ($tip)'),
                              );
                            }).toList();
                          },
                        ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  SizedBox(
                    width: 90,
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
                      decoration: const InputDecoration(labelText: 'Tarifa Aplicada'),
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
                  if (metodoPago.contains('Crédito')) {
                    estadoCobro = 'Pendiente';
                  } else if (!esDesdeCobros) {
                    estadoCobro = 'Pagado';
                  }
                }),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: estadoCobro,
                decoration: const InputDecoration(labelText: 'Estado del Cobro'),
                items: const [
                  DropdownMenuItem(value: 'Pagado', child: Text('Cobrado / Pagado (Cuenta como Venta)')),
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Primero crea el producto en la pestaña Stock.')));
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
        title: const Text('Registrar Compra a Proveedor'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                value: prodSel['id'] as int,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Producto Comprado'),
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
