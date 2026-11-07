import '../../domain/entities/expense_category.dart';

class ParsedNotificationExpense {
  const ParsedNotificationExpense({
    required this.amount,
    required this.merchant,
    required this.timestamp,
    this.category = ExpenseCategory.market,
  });

  final double amount;
  final String merchant;
  final DateTime timestamp;

  /// Categoria padrão "Mercado/Alimentação" (mercado).
  final ExpenseCategory category;
}

/// Extrai dados de compra de notificações bancárias no próprio dispositivo.
class NotificationParser {
  const NotificationParser({DateTime Function()? clock}) : _clock = clock;

  final DateTime Function()? _clock;

  static const _amount = r'((?:\d{1,3}(?:\.\d{3})+|\d+)(?:,\d{2})?)';

  static final RegExp _nubankPattern = RegExp(
    '\\bcompra\\s+de\\s+R\\\$\\s*$_amount'
    '\\s+no\\s+estabelecimento\\s+(.+?)\\s+aprovada\\b',
    caseSensitive: false,
  );
  static final RegExp _itauPattern = RegExp(
    '\\bcompra\\s+aprovada\\s+no\\s+seu\\s+cart[aã]o\\s+final\\s+\\d{4}'
    '\\s*[-–—]\\s*(.+?)\\s+R\\\$\\s*$_amount\\b',
    caseSensitive: false,
  );
  static final RegExp _interPattern = RegExp(
    '\\bvoc[eê]\\s+gastou\\s+R\\\$\\s*$_amount'
    '\\s+no\\s+estabelecimento\\s+(.+?)(?:[.!;]|(?![\\s\\S]))',
    caseSensitive: false,
  );
  // Fatura/Mercado Pago: "MP *MERCADINHO Osasco R$ 10,00 Cartão final 3694".
  // Aceita asteriscos/aspas variados e espaços ao redor do "*".
  static final RegExp _mercadoPagoPattern = RegExp(
    '(?:^|\\s)((?:MP|Mercado\\s*Pago)\\s*[*＊✱]\\s*[\'"“”‘’`´]*[^\\s*]'
    '.*?)\\s+R\\\$\\s*$_amount'
    '\\s+cart[aã]o\\s+final\\s+\\d{4}\\b',
    caseSensitive: false,
  );
  static final RegExp _mercadoPagoPrefix = RegExp(
    r'^(?:MP|Mercado\s*Pago)\s*[*＊✱]\s*',
    caseSensitive: false,
  );
  static final RegExp _genericAmountPattern = RegExp(
    'R\\\$\\s*$_amount',
    caseSensitive: false,
  );
  static final RegExp _transactionPattern = RegExp(
    r'\b(compra|pagamento|transa[cç][aã]o|d[eé]bito|cart[aã]o|gastou)\b',
    caseSensitive: false,
  );
  static final RegExp _merchantAfterAmount = RegExp(
    r'\b(?:em|no estabelecimento(?:\s+de)?|para)\s+(.+?)'
    r'(?=$|[.,;!?]|\s+(?:no seu|no|via|com final|cart[aã]o final)\b)',
    caseSensitive: false,
  );
  static final RegExp _merchantBeforeAmount = RegExp(
    r'\b(?:compra|pagamento)\b.{0,50}?\b(?:em|no estabelecimento(?:\s+de)?|'
    r'no(?!\s+(?:seu|valor)\b)|na)'
    r'\s+(.+?)\s+(?:no valor|por|de)\s+R\$',
    caseSensitive: false,
  );
  static final RegExp _merchantInTitle = RegExp(
    r'\b(?:em|no estabelecimento(?:\s+de)?|'
    r'no(?!\s+(?:seu\s+)?cart[aã]o\b|\s+valor\b)|na)\s+(.+?)\s*$',
    caseSensitive: false,
  );
  static final RegExp _boilerplateMerchant = RegExp(
    r'\b(?:seu cart[aã]o|cart[aã]o|valor|aprovad[ao])\b',
    caseSensitive: false,
  );

  ParsedNotificationExpense? parse({
    required String title,
    required String content,
    DateTime? timestamp,
  }) {
    final text = _cleanText('$title $content');
    final occurredAt = timestamp ?? _clock?.call() ?? DateTime.now();

    final bankSpecific = _parseBankPattern(text, occurredAt);
    if (bankSpecific != null) return bankSpecific;
    if (!_transactionPattern.hasMatch(text)) return null;

    final amountMatch = _genericAmountPattern.firstMatch(text);
    if (amountMatch == null) return null;
    final afterAmount = text.substring(amountMatch.end);
    final merchantMatch = _merchantAfterAmount.firstMatch(afterAmount) ??
        _merchantInTitle.firstMatch(_cleanText(title)) ??
        _merchantBeforeAmount.firstMatch(text);
    if (merchantMatch == null) return null;

    return _createExpense(
      amountMatch.group(1)!,
      merchantMatch.group(1)!,
      occurredAt,
    );
  }

  ParsedNotificationExpense? _parseBankPattern(
    String text,
    DateTime timestamp,
  ) {
    final nubank = _nubankPattern.firstMatch(text);
    if (nubank != null) {
      return _createExpense(nubank.group(1)!, nubank.group(2)!, timestamp);
    }

    final itau = _itauPattern.firstMatch(text);
    if (itau != null) {
      return _createExpense(itau.group(2)!, itau.group(1)!, timestamp);
    }

    final inter = _interPattern.firstMatch(text);
    if (inter != null) {
      return _createExpense(inter.group(1)!, inter.group(2)!, timestamp);
    }

    final mercadoPago = _mercadoPagoPattern.firstMatch(text);
    if (mercadoPago != null) {
      return _createExpense(
        mercadoPago.group(2)!,
        _mercadoPagoMerchant(mercadoPago.group(1)!),
        timestamp,
      );
    }

    return null;
  }

  /// Normaliza para "MP *NOME" e descarta a cidade (palavras em caixa mista
  /// após o último termo em caixa alta).
  static String _mercadoPagoMerchant(String raw) {
    final prefix = _mercadoPagoPrefix.firstMatch(raw)!;
    final name =
        raw.substring(prefix.end).replaceAll(RegExp('[\'"“”‘’`´*]'), '').trim();
    final words = name.split(' ').where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return '';
    var lastUpper = words.lastIndexWhere(
      (w) => w == w.toUpperCase() && w != w.toLowerCase(),
    );
    if (lastUpper < 0) lastUpper = 0;
    return 'MP *${words.take(lastUpper + 1).join(' ')}';
  }

  ParsedNotificationExpense? _createExpense(
    String rawAmount,
    String rawMerchant,
    DateTime timestamp,
  ) {
    final amount = double.tryParse(
      rawAmount.replaceAll('.', '').replaceAll(',', '.'),
    );
    final merchant = _cleanMerchant(rawMerchant);
    if (amount == null ||
        !amount.isFinite ||
        amount <= 0 ||
        merchant.isEmpty ||
        _boilerplateMerchant.hasMatch(merchant)) {
      return null;
    }

    return ParsedNotificationExpense(
      amount: amount,
      merchant:
          merchant.length > 80 ? merchant.substring(0, 80).trim() : merchant,
      timestamp: timestamp,
    );
  }

  static String _cleanText(String value) =>
      value.replaceAll(RegExp(r'\s+'), ' ').trim();

  static String _cleanMerchant(String value) => _cleanText(value).replaceAll(
        RegExp(r'[\s.!,;:–—-]+$'),
        '',
      );
}
