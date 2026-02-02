import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

void main() {
  runApp(const MyCalendarApp());
}

class MyCalendarApp extends StatelessWidget {
  const MyCalendarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Hores',
      theme: ThemeData.dark(),
      home: const CalendarPage(),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('it'),
      ],
    );
  }
}

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  Map<String, Map<String, dynamic>> _events = {};

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  String _keyForDay(DateTime day) => "${day.year}-${day.month}-${day.day}";

  double? _hoursFor(DateTime day) =>
      _events[_keyForDay(day)]?['hours']?.toDouble();

  String? _letterFor(DateTime day) =>
      _events[_keyForDay(day)]?['letter'] as String?;

  String? _noteFor(DateTime day) =>
      _events[_keyForDay(day)]?['note'] as String?;

  Future<void> _loadEvents() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString("events");
    if (raw != null) {
      final decoded = json.decode(raw) as Map<String, dynamic>;
      setState(() {
        _events =
            decoded.map((k, v) => MapEntry(k, Map<String, dynamic>.from(v)));
      });
    }
  }

  Future<void> _saveEvents() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("events", json.encode(_events));
  }

  /// DIALOG ORE/LETTERA
  Future<void> _showAddOrEditDialog(DateTime day) async {
    final key = _keyForDay(day);
    final current = _events[key] ?? {};
    double? value = current['hours']?.toDouble();
    String? letter = current['letter'] as String?;

    final valueController =
    TextEditingController(text: value?.toString() ?? '');
    final letterController = TextEditingController(text: letter ?? '');

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        content: SingleChildScrollView(
          child: Column(
            children: [
              Text(current.isEmpty ? "Aggiungi dato" : "Modifica dato"),
              const SizedBox(height: 12),
              TextField(
                controller: valueController,
                keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
                decoration:
                const InputDecoration(hintText: "Ore (es: 6 o 6.5)"),
                onChanged: (v) =>
                value = double.tryParse(v.replaceAll(',', '.')),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: letterController,
                textCapitalization: TextCapitalization.characters,
                maxLength: 1,
                decoration:
                const InputDecoration(hintText: "Lettera (es: P)"),
                onChanged: (v) =>
                letter = v.isNotEmpty ? v.toUpperCase() : null,
              ),
            ],
          ),
        ),
        actions: [
          if (current.isNotEmpty)
            TextButton(
              child: const Text("Cancella"),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: Colors.grey[900],
                    title: const Text("Conferma cancellazione"),
                    content: const Text("Eliminare questo dato?"),
                    actions: [
                      TextButton(
                        child: const Text("Annulla"),
                        onPressed: () => Navigator.pop(context, false),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red),
                        child: const Text("Cancella"),
                        onPressed: () => Navigator.pop(context, true),
                      ),
                    ],
                  ),
                );

                if (confirm == true) {
                  setState(() => _events.remove(key));
                  _saveEvents();
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Dato eliminato"),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
            ),
          TextButton(
            child: const Text("Annulla"),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            child: const Text("Salva"),
            onPressed: () {
              FocusScope.of(context).unfocus();

              final hasValue =
                  value != null && value! >= 0 && value! <= 23.5;
              final hasLetter = (letter ?? '').isNotEmpty;

              if (hasValue && hasLetter) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content:
                    Text("Non puoi inserire ore e lettera insieme"),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                return;
              }

              if (!hasValue && !hasLetter) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content:
                    Text("Inserisci almeno un'ora o una lettera"),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                return;
              }

              setState(() {
                final m = Map<String, dynamic>.from(_events[key] ?? {}); // mantiene 'note'
                if (hasValue) { m['hours'] = value; m.remove('letter'); }
                if (hasLetter) { m['letter'] = letter; m.remove('hours'); }
                _events[key] = m;
              });


              _saveEvents();

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Dato salvato correttamente"),
                  behavior: SnackBarBehavior.floating,
                ),
              );

              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  /// SCHERMATA NOTA
  Future<void> _openNoteScreen(DateTime day) async {
    final key = _keyForDay(day);
    String? note = _events[key]?['note'] as String?;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NotePage(
          day: day,
          note: note,
          onSave: (newNote) {
            setState(() {
              if (newNote.isEmpty) {
                _events[key]?.remove('note');
                if (_events[key]?.isEmpty ?? false) {
                  _events.remove(key);
                }
              } else {
                _events[key] ??= {};
                _events[key]!['note'] = newNote;
              }
            });
            _saveEvents();
          },
        ),
      ),
    );
  }

  /// TUTORIAL
  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text("Come usare il calendario"),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.touch_app, color: Colors.greenAccent),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                        "Tocca un giorno per aprire o modificare la nota."),
                  ),
                ],
              ),
              SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.edit, color: Colors.yellowAccent),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                        "Tieni premuto su un giorno per inserire ore o una lettera."),
                  ),
                ],
              ),
              SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.circle,
                      size: 14, color: Colors.orangeAccent),
                  SizedBox(width: 8),
                  Expanded(child: Text("Pallino arancione = nota presente.")),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            child: const Text("Chiudi"),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  /// CANCELLA TUTTO
  Future<void> _confirmClearAll() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text("Cancellare tutto?"),
        content: const Text("Questa azione eliminerà ogni dato salvato."),
        actions: [
          TextButton(
            child: const Text("Annulla"),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Cancella tutto"),
            onPressed: () async {
              Navigator.pop(context);
              final prefs = await SharedPreferences.getInstance();
              setState(() => _events.clear());
              prefs.remove("events");
            },
          ),
        ],
      ),
    );
  }

  double _getMonthTotal(DateTime month) {
    return _events.entries
        .where((e) => e.key.startsWith("${month.year}-${month.month}-"))
        .fold(
        0.0, (sum, e) => sum + (e.value['hours']?.toDouble() ?? 0));
  }

  String _formatHours(double value) =>
      value % 1 == 0 ? value.toInt().toString() : value.toString();

  /// CELLA GIORNO
  Widget _buildDayCell(DateTime day,
      {required bool isToday,
        required bool isSelected,
        required double? hours,
        required String? letter}) {
    final hasNote = _noteFor(day) != null;

    return GestureDetector(
      onTap: () => _openNoteScreen(day),
      onLongPress: () => _showAddOrEditDialog(day),
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? Colors.white70
                : isToday
                ? Colors.greenAccent
                : Colors.blue,
            width: isSelected || isToday ? 2 : 1,
          ),
        ),
        child: Stack(
          children: [
            Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Text("${day.day}",
                    style: TextStyle(
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal)),
              ),
            ),
            if (hasNote)
              const Positioned(
                top: 6,
                right: 6,
                child: CircleAvatar(
                  radius: 5,
                  backgroundColor: Colors.orangeAccent,
                ),
              ),
            if (hours != null && hours > 0)
              Align(
                alignment: const Alignment(0, 0.6),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: Colors.blueAccent,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _formatHours(hours),
                    style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            if (letter != null && letter.isNotEmpty)
              Center(
                child: Text(letter,
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue)),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalMonthHours = _getMonthTotal(_focusedDay);

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text("Hores"),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showInfoDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.blue,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              "Totale ore del mese: ${_formatHours(totalMonthHours)}",
              style:
              const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: TableCalendar(
              locale: 'it',
              focusedDay: _focusedDay,
              firstDay: DateTime.utc(2020, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),

              daysOfWeekHeight: 30, // 👈 AGGIUNGI QUESTA RIGA

              selectedDayPredicate: (d) => isSameDay(_selectedDay, d),
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
              },
              calendarFormat: CalendarFormat.month,
              headerStyle: const HeaderStyle(
                titleCentered: true,
                formatButtonVisible: false,
              ),
              daysOfWeekStyle: const DaysOfWeekStyle(
                weekdayStyle: TextStyle(color: Colors.white),
                weekendStyle: TextStyle(color: Colors.redAccent),
              ),
              calendarBuilders: CalendarBuilders(
                defaultBuilder: (context, day, _) => _buildDayCell(day,
                    isToday: false,
                    isSelected: false,
                    hours: _hoursFor(day),
                    letter: _letterFor(day)),
                todayBuilder: (context, day, _) => _buildDayCell(day,
                    isToday: true,
                    isSelected: false,
                    hours: _hoursFor(day),
                    letter: _letterFor(day)),
                selectedBuilder: (context, day, _) => _buildDayCell(day,
                    isToday: false,
                    isSelected: true,
                    hours: _hoursFor(day),
                    letter: _letterFor(day)),
              ),
              calendarStyle: const CalendarStyle(markersMaxCount: 0),
              rowHeight: 80,
            ),
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: FloatingActionButton(
          backgroundColor: Colors.redAccent,
          onPressed: _confirmClearAll,
          child: const Icon(Icons.delete),
        ),
      ),
    );
  }
}

class NotePage extends StatefulWidget {
  final DateTime day;
  final String? note;
  final Function(String) onSave;

  const NotePage(
      {super.key, required this.day, this.note, required this.onSave});

  @override
  State<NotePage> createState() => _NotePageState();
}

class _NotePageState extends State<NotePage> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.note ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _confirmDeleteNote() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text("Conferma eliminazione"),
        content: const Text("Vuoi eliminare questa nota?"),
        actions: [
          TextButton(
            child: const Text("Annulla"),
            onPressed: () => Navigator.pop(context, false),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Elimina"),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (confirm == true) {
      _controller.clear();
      widget.onSave("");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Nota eliminata"),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context);
    }
  }

  void _saveNote() {
    widget.onSave(_controller.text);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Nota salvata"),
        behavior: SnackBarBehavior.floating,
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
            "Nota del ${widget.day.day}/${widget.day.month}/${widget.day.year}"),
        actions: [
          if (_controller.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _confirmDeleteNote,
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              maxLines: null,
              decoration: const InputDecoration(
                hintText: "Inserisci la nota",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              child: const Text("Salva"),
              onPressed: _saveNote,
            ),
          ],
        ),
      ),
    );
  }
}
