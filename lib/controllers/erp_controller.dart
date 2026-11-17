import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/transaction_model.dart';

class ErpController {
  static final ErpController instance = ErpController._init();
  static Database? _database;

  ErpController._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('erp_juan_v1.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE transactions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            type TEXT,
            client TEXT,
            client_type TEXT,
            amount REAL,
            paid_amount REAL,
            payment_mode TEXT,
            has_delivery INTEGER,
            status TEXT,
            date TEXT
          )
        ''');

        String fechaHoy = DateTime.now().toString().substring(0, 10);

        // En PRODUCTO: amount = PVP Cliente Final, paid_amount = Precio Especial Colaborador, payment_mode = Costo Base
        await db.insert('transactions', {
          'type': 'PRODUCTO',
          'client': 'Mónaco',
          'client_type': 'General',
          'amount': 90.0,
          'paid_amount': 70.0,
          'payment_mode': '37.00',
          'has_delivery': 0,
          'status': 'Activo',
          'date': fechaHoy,
        });
        await db.insert('transactions', {
          'type': 'PRODUCTO',
          'client': 'Tíbet',
          'client_type': 'General',
          'amount': 0.0,
          'paid_amount': 0.0,
          'payment_mode': '0.00',
          'has_delivery': 0,
          'status': 'Stock Bajo',
          'date': fechaHoy,
        });
        await db.insert('transactions', {
          'type': 'PRODUCTO',
          'client': 'Granada',
          'client_type': 'General',
          'amount': 0.0,
          'paid_amount': 0.0,
          'payment_mode': '0.00',
          'has_delivery': 0,
          'status': 'Stock Bajo',
          'date': fechaHoy,
        });
        await db.insert('transactions', {
          'type': 'COMPRA',
          'client': 'Mónaco',
          'client_type': 'Proveedor',
          'amount': 37.0,
          'paid_amount': 37.0,
          'payment_mode': 'Contado',
          'has_delivery': 0,
          'status': 'Completada',
          'date': fechaHoy,
        });
        await db.insert('transactions', {
          'type': 'VENTA',
          'client': 'Cliente General (Mónaco)',
          'client_type': 'Cliente Final',
          'amount': 90.0,
          'paid_amount': 90.0,
          'payment_mode': 'Contado',
          'has_delivery': 0,
          'status': 'Completada',
          'date': fechaHoy,
        });
      },
    );
  }

  Future<List<TransactionModel>> getTransactions([String? typeFilter]) async {
    final db = await instance.database;
    final result = typeFilter == null || typeFilter == 'TODOS'
        ? await db.query('transactions', orderBy: 'id DESC')
        : await db.query('transactions', where: 'type = ?', whereArgs: [typeFilter], orderBy: 'id DESC');
    return result.map((json) => TransactionModel.fromMap(json)).toList();
  }

  Future<List<TransactionModel>> getPendingCobros() async {
    final db = await instance.database;
    final result = await db.query(
      'transactions',
      where: 'type = ? AND status != ?',
      whereArgs: ['COBRO', 'Cobrado'],
      orderBy: 'id DESC',
    );
    return result.map((json) => TransactionModel.fromMap(json)).toList();
  }

  Future<int> insertTransaction(TransactionModel transaction) async {
    final db = await instance.database;

    // RETROALIMENTACIÓN ENTRE MÓDULOS
    if (transaction.type == 'PRODUCTO') {
      // Si el producto ya existe, lo actualiza en lugar de duplicarlo
      final existing = await db.query(
        'transactions',
        where: 'type = ? AND LOWER(client) = ?',
        whereArgs: ['PRODUCTO', transaction.client.toLowerCase()],
      );
      if (existing.isNotEmpty) {
        return await db.update(
          'transactions',
          transaction.toMap(),
          where: 'id = ?',
          whereArgs: [existing.first['id']],
        );
      }
    } else if (transaction.type == 'COMPRA') {
      // Si se compra un producto registrado en Stock, activa su estado y actualiza su costo base
      final existingProd = await db.query(
        'transactions',
        where: 'type = ? AND LOWER(client) = ?',
        whereArgs: ['PRODUCTO', transaction.client.toLowerCase()],
      );
      if (existingProd.isNotEmpty) {
        double currentPvp = (existingProd.first['amount'] as num?)?.toDouble() ?? 0.0;
        await db.update(
          'transactions',
          {
            'status': 'Activo',
            'payment_mode': transaction.amount.toStringAsFixed(2),
            if (currentPvp <= 0) 'amount': transaction.amount,
          },
          where: 'id = ?',
          whereArgs: [existingProd.first['id']],
        );
      }
    }

    return await db.insert('transactions', transaction.toMap());
  }

  Future<int> updateProduct(int id, String name, double pvp, double specialPrice, double cost) async {
    final db = await instance.database;
    return await db.update(
      'transactions',
      {
        'client': name,
        'amount': pvp,
        'paid_amount': specialPrice,
        'payment_mode': cost.toStringAsFixed(2),
        'status': pvp > 0 ? 'Activo' : 'Stock Bajo',
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> markCobroAsPaid(int id, double amount) async {
    final db = await instance.database;
    return await db.update(
      'transactions',
      {'status': 'Cobrado', 'paid_amount': amount},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteTransaction(int id) async {
    final db = await instance.database;
    return await db.delete('transactions', where: 'id = ?', whereArgs: [id]);
  }

  Future<double> getSum(String type) async {
    final db = await instance.database;
    if (type == 'COBRO') {
      final res = await db.rawQuery("SELECT SUM(amount) as total FROM transactions WHERE type = 'COBRO' AND status != 'Cobrado'");
      return (res.first['total'] as num?)?.toDouble() ?? 0.0;
    }
    if (type == 'VENTA') {
      final resVentas = await db.rawQuery("SELECT SUM(amount) as total FROM transactions WHERE type = 'VENTA'");
      final resCobrados = await db.rawQuery("SELECT SUM(amount) as total FROM transactions WHERE type = 'COBRO' AND status = 'Cobrado'");
      double v = (resVentas.first['total'] as num?)?.toDouble() ?? 0.0;
      double c = (resCobrados.first['total'] as num?)?.toDouble() ?? 0.0;
      return v + c;
    }
    final res = await db.rawQuery('SELECT SUM(amount) as total FROM transactions WHERE type = ?', [type]);
    return (res.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  Future<int> getLowStockCount() async {
    final db = await instance.database;
    final res = await db.rawQuery("SELECT COUNT(*) as cnt FROM transactions WHERE type = 'PRODUCTO' AND amount <= 0");
    return (res.first['cnt'] as int?) ?? 0;
  }
}
