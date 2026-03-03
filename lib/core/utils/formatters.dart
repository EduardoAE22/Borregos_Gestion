import 'package:intl/intl.dart';

class AppFormatters {
  AppFormatters._();

  static final DateFormat _date = DateFormat('dd/MM/yyyy');
  static final NumberFormat _money = NumberFormat.currency(
    locale: 'es_MX',
    symbol: r'$',
  );

  static String date(DateTime date) {
    return _date.format(DateTime(date.year, date.month, date.day));
  }

  static String money(num value) {
    return _money.format(value);
  }
}
