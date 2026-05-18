import 'dart:convert';

enum MessageRole { user, assistant, error, resultado }

class IaMessage {
  final String id;
  final MessageRole role;
  final String text;
  final Map<String, dynamic>? parsedJson;
  final List<Map<String, dynamic>>? parsedJsonList; // multi-intent
  final DateTime timestamp;
  final bool isLoading;

  IaMessage({
    required this.id,
    required this.role,
    required this.text,
    this.parsedJson,
    this.parsedJsonList,
    DateTime? timestamp,
    this.isLoading = false,
  }) : timestamp = timestamp ?? DateTime.now();

  factory IaMessage.user(String text) => IaMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        role: MessageRole.user,
        text: text,
      );

  factory IaMessage.loading() => IaMessage(
        id: 'loading',
        role: MessageRole.assistant,
        text: '',
        isLoading: true,
      );

  factory IaMessage.fromResponse(String jsonText) {
    Map<String, dynamic>? parsed;
    List<Map<String, dynamic>>? parsedList;

    try {
      final decoded = jsonDecode(jsonText);
      if (decoded is List) {
        // Filtrar elementos con tool vacío o inválido
        final lista = decoded
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .where((e) =>
                e['tool'] != null &&
                e['tool'].toString().isNotEmpty &&
                e['tool'].toString() != 'desconocido')
            .toList();

        if (lista.isNotEmpty) {
          parsedList = lista;
        }
      } else if (decoded is Map<String, dynamic>) {
        final tool = decoded['tool']?.toString() ?? '';
        if (tool.isNotEmpty && tool != 'desconocido') {
          parsed = decoded;
        }
      }
    } catch (_) {}

    return IaMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      role: MessageRole.assistant,
      text: jsonText,
      parsedJson: parsed,
      parsedJsonList: parsedList,
    );
  }

  factory IaMessage.error(String message) => IaMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        role: MessageRole.error,
        text: message,
      );

  factory IaMessage.resultado(String mensaje) => IaMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        role: MessageRole.resultado,
        text: mensaje,
      );

  bool get hasStructuredData => parsedJson != null || parsedJsonList != null;
  bool get hasMultipleActions =>
      parsedJsonList != null && parsedJsonList!.length > 1;

  String get actionLabel {
    if (parsedJsonList != null) {
      if (parsedJsonList!.length > 1) {
        return '${parsedJsonList!.length} acciones detectadas';
      }
      if (parsedJsonList!.isNotEmpty) {
        final tool = parsedJsonList!.first['tool'] ?? '';
        final action = parsedJsonList!.first['action'] ?? '';
        return '$tool → $action';
      }
    }
    if (parsedJson == null) return '';
    final tool = parsedJson!['tool'] ?? '';
    final action = parsedJson!['action'] ?? '';
    return '$tool → $action';
  }
}
