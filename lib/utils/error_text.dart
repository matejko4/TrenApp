/// Text chyby pro uživatele – bez prefixu „Exception: “, který přidává
/// `Exception.toString()` (služby hlásí chyby přes `throw Exception('…')`).
String errorText(Object error) =>
    error.toString().replaceFirst('Exception: ', '');
