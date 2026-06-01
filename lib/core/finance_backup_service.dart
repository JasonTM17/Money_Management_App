import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';

import 'finance_models.dart';

class FinanceBackupData {
  const FinanceBackupData({
    required this.wallets,
    required this.categories,
    required this.transactions,
    required this.budgets,
    required this.goals,
  });

  final List<WalletAccount> wallets;
  final List<FinanceCategory> categories;
  final List<FinanceTransaction> transactions;
  final List<Budget> budgets;
  final List<SavingGoal> goals;
}

class FinanceBackupPreview {
  const FinanceBackupPreview({
    required this.walletCount,
    required this.transactionCount,
    required this.budgetCount,
    required this.goalCount,
    this.exportedAt,
    this.schemaVersion = 1,
    this.encrypted = false,
  });

  final int walletCount;
  final int transactionCount;
  final int budgetCount;
  final int goalCount;
  final DateTime? exportedAt;
  final int schemaVersion;
  final bool encrypted;
}

class FinanceBackupService {
  const FinanceBackupService();

  static const _schemaVersionPlainJson = 1;
  static const _schemaVersionEncrypted = 2;
  static const _kdfIterations = 210000;
  static final _cipher = AesGcm.with256bits();
  static final _kdf = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: _kdfIterations,
    bits: 256,
  );

  String encode({
    required List<WalletAccount> wallets,
    required List<FinanceCategory> categories,
    required List<FinanceTransaction> transactions,
    required List<Budget> budgets,
    required List<SavingGoal> goals,
  }) {
    return const JsonEncoder.withIndent('  ').convert({
      'app': 'cashflow_manager',
      'schemaVersion': _schemaVersionPlainJson,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'wallets': wallets.map(_walletToJson).toList(),
      'categories': categories.map(_categoryToJson).toList(),
      'transactions': transactions.map(_transactionToJson).toList(),
      'budgets': budgets.map(_budgetToJson).toList(),
      'goals': goals.map(_goalToJson).toList(),
    });
  }

  Future<String> encodeEncrypted({
    required List<WalletAccount> wallets,
    required List<FinanceCategory> categories,
    required List<FinanceTransaction> transactions,
    required List<Budget> budgets,
    required List<SavingGoal> goals,
    required String passphrase,
  }) async {
    _validatePassphrase(passphrase);
    final exportedAt = DateTime.now().toUtc();
    final plaintext = encode(
      wallets: wallets,
      categories: categories,
      transactions: transactions,
      budgets: budgets,
      goals: goals,
    );
    final salt = _randomBytes(16);
    final nonce = _randomBytes(12);
    final secretKey = await _deriveKey(passphrase, salt);
    final box = await _cipher.encrypt(
      utf8.encode(plaintext),
      secretKey: secretKey,
      nonce: nonce,
    );
    return const JsonEncoder.withIndent('  ').convert({
      'app': 'cashflow_manager',
      'schemaVersion': _schemaVersionEncrypted,
      'encrypted': true,
      'exportedAt': exportedAt.toIso8601String(),
      'encryption': {
        'algorithm': 'AES-256-GCM',
        'kdf': 'PBKDF2-HMAC-SHA256',
        'iterations': _kdfIterations,
        'salt': base64UrlEncode(salt),
        'nonce': base64UrlEncode(nonce),
      },
      'ciphertext': base64UrlEncode(box.cipherText),
      'mac': base64UrlEncode(box.mac.bytes),
    });
  }

  bool isEncrypted(String input) {
    try {
      final root = _rawRoot(input);
      return root['app'] == 'cashflow_manager' &&
          root['schemaVersion'] == _schemaVersionEncrypted &&
          root['encrypted'] == true;
    } on Object {
      return false;
    }
  }

  Future<String> decryptToPlaintext(
    String input, {
    required String passphrase,
  }) async {
    _validatePassphrase(passphrase);
    final root = _encryptedRoot(input);
    final encryption = _map(root['encryption']);
    if (encryption['algorithm'] != 'AES-256-GCM' ||
        encryption['kdf'] != 'PBKDF2-HMAC-SHA256' ||
        encryption['iterations'] != _kdfIterations) {
      throw const FormatException('backupUnsupportedVersion');
    }
    final salt = _base64List(encryption, 'salt');
    final nonce = _base64List(encryption, 'nonce');
    final cipherText = _base64List(root, 'ciphertext');
    final mac = _base64List(root, 'mac');
    try {
      final secretKey = await _deriveKey(passphrase, salt);
      final clearBytes = await _cipher.decrypt(
        SecretBox(cipherText, nonce: nonce, mac: Mac(mac)),
        secretKey: secretKey,
      );
      final plaintext = utf8.decode(clearBytes);
      _root(plaintext);
      return plaintext;
    } on FormatException {
      rethrow;
    } on Object {
      throw const FormatException('backupDecryptFailed');
    }
  }

  FinanceBackupPreview preview(String input) {
    final root = _root(input);
    return FinanceBackupPreview(
      walletCount: _list(root, 'wallets').length,
      transactionCount: _list(root, 'transactions').length,
      budgetCount: _list(root, 'budgets').length,
      goalCount: _list(root, 'goals').length,
      exportedAt: _optionalDateTime(root['exportedAt']),
      schemaVersion: _schemaVersionPlainJson,
    );
  }

  FinanceBackupData decode(String input) {
    final root = _root(input);
    final wallets = _list(root, 'wallets').map(_walletFromJson).toList();
    final categories = _list(
      root,
      'categories',
    ).map(_categoryFromJson).toList();
    final transactions = _list(
      root,
      'transactions',
    ).map(_transactionFromJson).toList();
    final budgets = _list(root, 'budgets').map(_budgetFromJson).toList();
    final goals = _list(root, 'goals').map(_goalFromJson).toList();
    if (wallets.isEmpty) {
      throw const FormatException('backupWalletRequired');
    }
    if (categories.isEmpty) {
      throw const FormatException('backupCategoryRequired');
    }
    _validateIds(wallets.map((item) => item.id));
    _validateIds(categories.map((item) => item.id));
    _validateIds(transactions.map((item) => item.id));
    _validateIds(budgets.map((item) => item.id));
    _validateIds(goals.map((item) => item.id));
    _validateReferences(
      wallets: wallets,
      categories: categories,
      transactions: transactions,
      budgets: budgets,
    );
    return FinanceBackupData(
      wallets: wallets,
      categories: categories,
      transactions: transactions,
      budgets: budgets,
      goals: goals,
    );
  }

  Future<SecretKey> _deriveKey(String passphrase, List<int> salt) {
    return _kdf.deriveKey(
      secretKey: SecretKey(utf8.encode(passphrase)),
      nonce: salt,
    );
  }

  List<int> _randomBytes(int length) {
    final random = Random.secure();
    return List<int>.generate(length, (_) => random.nextInt(256));
  }

  void _validatePassphrase(String passphrase) {
    if (passphrase.trim().length < 8) {
      throw const FormatException('backupPassphraseTooShort');
    }
  }

  Map<String, Object?> _walletToJson(WalletAccount item) => {
    'id': item.id,
    'name': item.name,
    'type': item.type.name,
    'initialBalance': item.initialBalance,
  };

  Map<String, Object?> _categoryToJson(FinanceCategory item) => {
    'id': item.id,
    'name': item.name,
    'type': item.type.name,
    'colorHex': item.colorHex,
  };

  Map<String, Object?> _transactionToJson(FinanceTransaction item) => {
    'id': item.id,
    'walletId': item.walletId,
    'toWalletId': item.toWalletId,
    'categoryId': item.categoryId,
    'type': item.type.name,
    'amount': item.amount,
    'date': item.date.toIso8601String(),
    'note': item.note,
    'isRecurring': item.isRecurring,
  };

  Map<String, Object?> _budgetToJson(Budget item) => {
    'id': item.id,
    'categoryId': item.categoryId,
    'month': item.month.toIso8601String(),
    'limitAmount': item.limitAmount,
  };

  Map<String, Object?> _goalToJson(SavingGoal item) => {
    'id': item.id,
    'name': item.name,
    'targetAmount': item.targetAmount,
    'savedAmount': item.savedAmount,
    'deadline': item.deadline.toIso8601String(),
  };

  WalletAccount _walletFromJson(Object? value) {
    final item = _map(value);
    return WalletAccount(
      id: _string(item, 'id'),
      name: _string(item, 'name'),
      type: _walletType(item, 'type'),
      initialBalance: _nonNegativeInt(item, 'initialBalance'),
    );
  }

  FinanceCategory _categoryFromJson(Object? value) {
    final item = _map(value);
    return FinanceCategory(
      id: _string(item, 'id'),
      name: _string(item, 'name'),
      type: _transactionType(item, 'type'),
      colorHex: _nonNegativeInt(item, 'colorHex'),
    );
  }

  FinanceTransaction _transactionFromJson(Object? value) {
    final item = _map(value);
    return FinanceTransaction(
      id: _string(item, 'id'),
      walletId: _string(item, 'walletId'),
      toWalletId: item['toWalletId'] == null
          ? null
          : _string(item, 'toWalletId'),
      categoryId: _string(item, 'categoryId'),
      type: _transactionType(item, 'type'),
      amount: _positiveInt(item, 'amount'),
      date: _dateTime(item, 'date'),
      note: _string(item, 'note'),
      isRecurring: _bool(item, 'isRecurring'),
    );
  }

  Budget _budgetFromJson(Object? value) {
    final item = _map(value);
    return Budget(
      id: _string(item, 'id'),
      categoryId: _string(item, 'categoryId'),
      month: _dateTime(item, 'month'),
      limitAmount: _positiveInt(item, 'limitAmount'),
    );
  }

  SavingGoal _goalFromJson(Object? value) {
    final item = _map(value);
    final targetAmount = _positiveInt(item, 'targetAmount');
    final savedAmount = _nonNegativeInt(item, 'savedAmount');
    if (savedAmount > targetAmount) {
      throw const FormatException('goalSavedExceedsTarget');
    }
    return SavingGoal(
      id: _string(item, 'id'),
      name: _string(item, 'name'),
      targetAmount: targetAmount,
      savedAmount: savedAmount,
      deadline: _dateTime(item, 'deadline'),
    );
  }

  Map<String, Object?> _root(String input) {
    final root = _rawRoot(input);
    if (root['app'] != 'cashflow_manager') {
      throw const FormatException('backupInvalidFile');
    }
    if (root['schemaVersion'] == _schemaVersionEncrypted) {
      throw const FormatException('backupEncryptedPassphraseRequired');
    }
    if (root['schemaVersion'] != _schemaVersionPlainJson) {
      throw const FormatException('backupUnsupportedVersion');
    }
    _optionalDateTime(root['exportedAt']);
    return root;
  }

  Map<String, Object?> _encryptedRoot(String input) {
    final root = _rawRoot(input);
    if (root['app'] != 'cashflow_manager' ||
        root['schemaVersion'] != _schemaVersionEncrypted ||
        root['encrypted'] != true) {
      throw const FormatException('backupUnsupportedVersion');
    }
    _optionalDateTime(root['exportedAt']);
    return root;
  }

  Map<String, Object?> _rawRoot(String input) {
    final root = jsonDecode(input);
    if (root is! Map<String, Object?>) {
      throw const FormatException('backupInvalidFile');
    }
    return root;
  }

  DateTime? _optionalDateTime(Object? value) {
    if (value == null) return null;
    if (value is String && value.trim().isNotEmpty) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) return parsed;
    }
    throw const FormatException('backupInvalidExportTime');
  }

  List<Object?> _list(Map<String, Object?> root, String key) {
    final value = root[key];
    if (value is List) return value.cast<Object?>();
    throw const FormatException('backupMissingData');
  }

  Map<String, Object?> _map(Object? value) {
    if (value is Map<String, Object?>) return value;
    throw const FormatException('backupInvalidRow');
  }

  List<int> _base64List(Map<String, Object?> item, String key) {
    final value = item[key];
    if (value is! String || value.trim().isEmpty) {
      throw const FormatException('backupMissingField');
    }
    try {
      return base64Url.decode(value);
    } on FormatException {
      throw const FormatException('backupInvalidFile');
    }
  }

  String _string(Map<String, Object?> item, String key) {
    final value = item[key];
    if (value is String && value.trim().isNotEmpty) return value;
    throw const FormatException('backupMissingField');
  }

  int _positiveInt(Map<String, Object?> item, String key) {
    final value = item[key];
    if (value is int && value > 0) return value;
    throw const FormatException('backupPositiveNumberRequired');
  }

  int _nonNegativeInt(Map<String, Object?> item, String key) {
    final value = item[key];
    if (value is int && value >= 0) return value;
    throw const FormatException('backupNonNegativeNumberRequired');
  }

  bool _bool(Map<String, Object?> item, String key) {
    final value = item[key];
    if (value is bool) return value;
    throw const FormatException('backupMissingField');
  }

  WalletType _walletType(Map<String, Object?> item, String key) {
    try {
      return WalletType.values.byName(_string(item, key));
    } on ArgumentError {
      throw const FormatException('backupInvalidType');
    }
  }

  TransactionType _transactionType(Map<String, Object?> item, String key) {
    try {
      return TransactionType.values.byName(_string(item, key));
    } on ArgumentError {
      throw const FormatException('backupInvalidType');
    }
  }

  DateTime _dateTime(Map<String, Object?> item, String key) {
    final parsed = DateTime.tryParse(_string(item, key));
    if (parsed != null) return parsed;
    throw const FormatException('backupInvalidDate');
  }

  void _validateIds(Iterable<String> ids) {
    final seen = <String>{};
    for (final id in ids) {
      if (!seen.add(id)) throw const FormatException('backupDuplicateId');
    }
  }

  void _validateReferences({
    required List<WalletAccount> wallets,
    required List<FinanceCategory> categories,
    required List<FinanceTransaction> transactions,
    required List<Budget> budgets,
  }) {
    final walletIds = wallets.map((item) => item.id).toSet();
    final categoryIds = categories.map((item) => item.id).toSet();
    for (final transaction in transactions) {
      if (!walletIds.contains(transaction.walletId)) {
        throw const FormatException('backupMissingWalletReference');
      }
      final targetId = transaction.toWalletId;
      if (targetId != null && !walletIds.contains(targetId)) {
        throw const FormatException('backupMissingTargetWalletReference');
      }
      if (!categoryIds.contains(transaction.categoryId)) {
        throw const FormatException('backupMissingCategoryReference');
      }
    }
    for (final budget in budgets) {
      if (!categoryIds.contains(budget.categoryId)) {
        throw const FormatException('backupMissingCategoryReference');
      }
    }
  }
}
