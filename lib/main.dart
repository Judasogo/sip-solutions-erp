import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ErpJuanApp());
}

class ErpJuanApp extends StatelessWidget {
  const ErpJuanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ERP Juan',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF3B82F6),
          secondary: Color(0xFF10B981),
          surface: Color(0xFF1E293B),
        ),
        cardColor: const Color(0xFF1E293B),
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
    _database = await _initDB('erp_juan.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS productos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL,
        precio_pvp REAL NOT NULL,
        precio_colaborador REAL NOT NULL,
        stock INTEGER NOT NULL DEFAULT 0,
        stock_minimo INTEGER NOT NULL DEFAULT 5
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS clientes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL,
        categoria TEXT NOT NULL,
        telefono TEXT,
        notas TEXT,
        rol TEXT DEFAULT 'N/A'
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS movimientos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        tipo TEXT NOT NULL,
        producto_id INTEGER,
        contacto_id INTEGER,
        cantidad INTEGER NOT NULL,
        total REAL NOT NULL,
        estado_pago TEXT NOT NULL,
        fecha TEXT NOT NULL
      )
    ''');
  }

  // --- CRUD CONTACTOS (Conservando registros existentes) ---
  Future<List>> getContactos({String? categoria, String? query}) async {
    final db = await instance.database;
    String whereClause = '';
    List<dynamic> whereArgs = [];

    if (categoria != null && categoria != 'Todos') {
      whereClause = 'categoria = ?';
      whereArgs.add(categoria);
    }

    if (query != null && query.isNotEmpty) {
      if (whereClause.isNotEmpty) whereClause += ' AND ';
      whereClause += '(nombre LIKE ? OR telefono LIKE ?)';
      whereArgs.add('%$query%');
      whereArgs.add('%$query%');
    }

    return await db.query(
      'clientes',
      where: whereClause.isEmpty ? null : whereClause,
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      orderBy: 'id DESC',
    );
  }

  Future<int> insertContacto(Map<String, dynamic> row) async {
    final db = await instance.database;
    // Asegura compatibilidad si la tabla ya tenía la columna 'rol'
    final columns = await db.rawQuery('PRAGMA table_info(clientes)');
    final hasRol = columns.any((col) => col['name'] == 'rol');
    final data = Map<String, dynamic>.from(row);
    if (!hasRol) {
      data.remove('rol');
    }
    return await db.insert('clientes', data);
  }

  Future<int> deleteContacto(int id) async {
    final db = await instance.database;
    return await db.delete('clientes', where: 'id = ?', whereArgs: [id]);
  }

  // --- CRUD PRODUCTOS ---
  Future<List>> getProductos() async {
    final db = await instance.database;
    return await db.query('productos', orderBy: 'nombre ASC');
  }

  Future<int> insertProducto(Map<String, dynamic> row) async {
    final db = await instance.database;
    return await db.insert('productos', row);
  }

  // --- CRUD MOVIMIENTOS ---
  Future<List>> getMovimientos({String? tipo}) async {
    final db = await instance.database;
    return await db.query(
      'movimientos',
      where: tipo != null ? 'tipo = ?' : null,
      whereArgs: tipo != null ? [tipo] : null,
      orderBy: 'id DESC',
    );
  }

  Future<int> insertMovimiento(Map<String, dynamic> row) async {
    final db = await instance.database;
    return await db.insert('movimientos', row);
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;
  String _perfilActivo = 'Administrador'; // 'Administrador' o 'Empleado'

  void _cambiarPerfil(String nuevoPerfil) {
    setState(() {
      _perfilActivo = nuevoPerfil;
      // Si el empleado estaba en una pestaña exclusiva de admin, volver a Inicio
      if (_perfilActivo == 'Empleado' && _selectedIndex > 2) {
        _selectedIndex = 0;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool esAdmin = _perfilActivo == 'Administrador';

    final List<Widget> pages = esAdmin
        ? [
            DashboardScreen(perfilActivo: _perfilActivo, onCambiarPerfil: _cambiarPerfil),
            const VentasScreen(),
            const StockScreen(),
            const CobrosScreen(),
            const KardexScreen(),
            const AgendaComercialScreen(),
          ]
        : [
            DashboardScreen(perfilActivo: _perfilActivo, onCambiarPerfil: _cambiarPerfil),
            const VentasScreen(),
            const StockScreen(),
          ];

    final List<BottomNavigationBarItem> navItems = esAdmin
        ? const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Inicio'),
            BottomNavigationBarItem(icon: Icon(Icons.receipt_long), label: 'Ventas'),
            BottomNavigationBarItem(icon: Icon(Icons.local_offer), label: 'Stock'),
            BottomNavigationBarItem(icon: Icon(Icons.access_time), label: 'Cobros'),
            BottomNavigationBarItem(icon: Icon(Icons.swap_vert), label: 'Kardex'),
            BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Clientes'),
          ]
        : const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Inicio'),
            BottomNavigationBarItem(icon: Icon(Icons.receipt_long), label: 'Ventas'),
            BottomNavigationBarItem(icon: Icon(Icons.local_offer), label: 'Stock'),
          ];

    return Scaffold(
      body: SafeArea(child: pages[_selectedIndex]),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        type: BottomNavigationBarType.fixed,
        backgroundColor: const Color(0xFF0B1120),
        selectedItemColor: const Color(0xFF3B82F6),
        unselectedItemColor: Colors.grey,
        selectedFontSize: 11,
        unselectedFontSize: 11,
        items: navItems,
      ),
    );
  }
}

class DashboardScreen extends StatelessWidget {
  final String perfilActivo;
  final Function(String) onCambiarPerfil;

  const DashboardScreen({
    super.key,
    required this.perfilActivo,
    required this.onCambiarPerfil,
  });

  @override
  Widget build(BuildContext context) {
    final bool esAdmin = perfilActivo == 'Administrador';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Cabecera con selector de Perfil activo (separado de Clientes)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white10),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('ERP', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'ERP Juan',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white10,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('v1.2', style: TextStyle(fontSize: 11)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.circle, size: 8, color: Color(0xFF10B981)),
                        const SizedBox(width: 6),
                        Text(
                          esAdmin ? 'Modo Administrador' : 'Modo Empleado',
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              DropdownButtonHideUnderline(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: DropdownButton<String>(
                    value: perfilActivo,
                    dropdownColor: const Color(0xFF1E293B),
                    style: const TextStyle(fontSize: 12, color: Colors.white),
                    items: const [
                      DropdownMenuItem(value: 'Administrador', child: Text('Admin')),
                      DropdownMenuItem(value: 'Empleado', child: Text('Empleado')),
                    ],
                    onChanged: (val) {
                      if (val != null) onCambiarPerfil(val);
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (esAdmin) ...[
          Row(
            children: [
              Expanded(
                child: _metricCard('Por Cobrar', '€ 0,00', 'Cuentas pendientes', Icons.schedule, Colors.orange),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _metricCard('Ingresos', '€ 0,00', 'Ventas totales', Icons.euro, const Color(0xFF10B981)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _metricCard('Valor Stock', '€ 0,00', 'Inventario activo', Icons.inventory_2, const Color(0xFF3B82F6)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _metricCard('Stock Bajo', '0 Prod.', 'Revisar reposición', Icons.warning_amber, Colors.amber),
              ),
            ],
          ),
        ] else ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Acceso Operativo (Empleado)',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  'Puedes registrar ventas y consultar el inventario disponible desde la barra inferior.',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _metricCard(String title, String value, String subtitle, IconData icon, Color accent) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(color: Colors.white70, fontSize: 12)),
              Icon(icon, size: 16, color: accent),
            ],
          ),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(color: accent, fontSize: 11)),
        ],
      ),
    );
  }
}

class AgendaComercialScreen extends StatefulWidget {
  const AgendaComercialScreen({super.key});

  @override
  State<AgendaComercialScreen> createState() => _AgendaComercialScreenState();
}

class _AgendaComercialScreenState extends State<AgendaComercialScreen> {
  String _filtroCategoria = 'Todos';
  String _busqueda = '';
  List> _contactos = [];
  int _totalTodos = 0;
  int _totalClientes = 0;
  int _totalColaboradores = 0;
  int _totalProveedores = 0;

  @override
  void initState() {
    super.initState();
    _cargarContactos();
  }

  Future<void> _cargarContactos() async {
    final todos = await DatabaseHelper.instance.getContactos();
    final filtrados = await DatabaseHelper.instance.getContactos(
      categoria: _filtroCategoria,
      query: _busqueda,
    );

    if (!mounted) return;
    setState(() {
      _contactos = filtrados;
      _totalTodos = todos.length;
      _totalClientes = todos.where((c) => c['categoria'] == 'Cliente').length;
      _totalColaboradores = todos.where((c) => c['categoria'] == 'Colaborador').length;
      _totalProveedores = todos.where((c) => c['categoria'] == 'Proveedor').length;
    });
  }

  void _mostrarDialogoAgregarContacto() {
    final nombreCtrl = TextEditingController();
    final telefonoCtrl = TextEditingController();
    final notasCtrl = TextEditingController();
    String categoriaSeleccionada = 'Cliente';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Agregar contacto', style: TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nombreCtrl,
                  decoration: InputDecoration(
                    hintText: 'Nombre o empresa',
                    filled: true,
                    fillColor: const Color(0xFF0F172A),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: categoriaSeleccionada,
                  dropdownColor: const Color(0xFF1E293B),
                  decoration: InputDecoration(
                    labelText: 'Categoría',
                    filled: true,
                    fillColor: const Color(0xFF0F172A),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Cliente', child: Text('Cliente (Tarifa PVP)')),
                    DropdownMenuItem(value: 'Colaborador', child: Text('Colaborador (Tarifa especial)')),
                    DropdownMenuItem(value: 'Proveedor', child: Text('Proveedor (Compras / Stock)')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() => categoriaSeleccionada = val);
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: telefonoCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    hintText: 'Teléfono / WhatsApp',
                    filled: true,
                    fillColor: const Color(0xFF0F172A),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notasCtrl,
                  decoration: InputDecoration(
                    hintText: 'Notas / Dirección / Referencia',
                    filled: true,
                    fillColor: const Color(0xFF0F172A),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar', style: TextStyle(color: Colors.white70)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              onPressed: () async {
                if (nombreCtrl.text.trim().isEmpty) return;
                await DatabaseHelper.instance.insertContacto({
                  'nombre': nombreCtrl.text.trim(),
                  'categoria': categoriaSeleccionada,
                  'telefono': telefonoCtrl.text.trim(),
                  'notas': notasCtrl.text.trim(),
                  'rol': 'N/A',
                });
                if (!mounted) return;
                Navigator.pop(ctx);
                _cargarContactos();
              },
              child: const Text('Guardar', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Agenda comercial',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Clientes, colaboradores con tarifa especial y proveedores.',
                      style: TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1D4ED8),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _mostrarDialogoAgregarContacto,
                icon: const Icon(Icons.person_add, size: 18),
                label: const Text('Agregar'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _chipFiltro('Todos', 'Todos ($_totalTodos)'),
                const SizedBox(width: 8),
                _chipFiltro('Cliente', 'Clientes ($_totalClientes)'),
                const SizedBox(width: 8),
                _chipFiltro('Colaborador', 'Colaboradores ($_totalColaboradores)'),
                const SizedBox(width: 8),
                _chipFiltro('Proveedor', 'Proveedores ($_totalProveedores)'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            onChanged: (val) {
              _busqueda = val;
              _cargarContactos();
            },
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search, color: Colors.white54),
              hintText: 'Buscar por nombre o teléfono...',
              filled: true,
              fillColor: const Color(0xFF1E293B),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _contactos.isEmpty
                ? const Center(
                    child: Text('No hay contactos registrados', style: TextStyle(color: Colors.white54)),
                  )
                : ListView.builder(
                    itemCount: _contactos.length,
                    itemBuilder: (context, index) {
                      final item = _contactos[index];
                      final cat = item['categoria'] ?? 'Cliente';
                      IconData icon = Icons.person;
                      Color badgeColor = const Color(0xFF3B82F6);
                      if (cat == 'Colaborador') {
                        icon = Icons.handshake;
                        badgeColor = Colors.amber;
                      } else if (cat == 'Proveedor') {
                        icon = Icons.local_shipping;
                        badgeColor = const Color(0xFF10B981);
                      }

                      return Card(
                        color: const Color(0xFF1E293B),
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: badgeColor.withOpacity(0.15),
                            child: Icon(icon, color: badgeColor, size: 20),
                          ),
                          title: Text(
                            item['nombre'] ?? '',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$cat • ${item['telefono'] ?? 'Sin teléfono'}',
                                style: const TextStyle(color: Colors.white70, fontSize: 12),
                              ),
                              if ((item['notas'] ?? '').toString().isNotEmpty)
                                Text(
                                  item['notas'],
                                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                                ),
                            ],
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.white54),
                            onPressed: () async {
                              await DatabaseHelper.instance.deleteContacto(item['id']);
                              _cargarContactos();
                            },
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

  Widget _chipFiltro(String valor, String etiqueta) {
    final bool seleccionado = _filtroCategoria == valor;
    return ChoiceChip(
      label: Text(etiqueta),
      selected: seleccionado,
      onSelected: (_) {
        setState(() => _filtroCategoria = valor);
        _cargarContactos();
      },
      selectedColor: const Color(0xFF1D4ED8),
      backgroundColor: const Color(0xFF1E293B),
      labelStyle: TextStyle(
        color: seleccionado ? Colors.white : Colors.white70,
        fontSize: 12,
      ),
    );
  }
}

class VentasScreen extends StatelessWidget {
  const VentasScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Módulo de Ventas', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
    );
  }
}

class StockScreen extends StatelessWidget {
  const StockScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Módulo de Stock e Inventario', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
    );
  }
}

class CobrosScreen extends StatelessWidget {
  const CobrosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Módulo de Cobros', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
    );
  }
}

class KardexScreen extends StatelessWidget {
  const KardexScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Módulo de Kardex', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
    );
  }
}
