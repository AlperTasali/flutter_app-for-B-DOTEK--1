import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() => runApp(const MyApp());
// 1-) GİRİŞ KISMI
class MyApp extends StatelessWidget {
    const MyApp({super.key});

    @override
    Widget build(BuildContext context) {
        return MaterialApp(
            debugShowCheckedModeBanner: false,
            home: PageControllerWidget(),
        );
    }
}

enum ReadForm { readout, lp, obis }
//2-) SatetfullWidget hareketli widget özelliği ile içeride değişebilen verileri sağlar
class PageControllerWidget extends StatefulWidget {
    @override
    State<PageControllerWidget> createState() => _PageControllerWidgetState();
}

class _PageControllerWidgetState extends State<PageControllerWidget> {
    final PageController _pageController = PageController();

    final _nameCtrl = TextEditingController();
    final _passCtrl = TextEditingController();
    final _deviceCtrl = TextEditingController();

    Map<String, dynamic>? _finalJson;
    Map<String, dynamic>? _userOverrides;

//3-) Cihaz Bilgileri Kısmında http adresinin bulunduğu kısmı göstermektedir
    String _apiBaseUrl = "http://127.0.0.1:8000";


    ReadForm _activeForm = ReadForm.readout;

    bool _showFormPanel = false;
    final _roSnCtrl = TextEditingController();
    final _roOptionsCtrl = TextEditingController(
        text: "0,6,7,8,9 0=[ACK]050[CR][LF],6=[ACK]056[CR][LF], 7=[ACK]057[CR][LF]",
    );
    String _roPort = "mxc1";


    final _lpSnCtrl = TextEditingController();
    String _lpPort = "mxc1";
    DateTime? _lpStart;
    DateTime? _lpEnd;

    // Obis form alanları
    final _obSnCtrl = TextEditingController();
    String _obPort = "mxc1";
    final _obListCtrl = TextEditingController(text: "1.8.0,32.7.0");


    Future<void> _fetchFromApi() async {
        final raw = _deviceCtrl.text.trim();
        if (raw.isEmpty) {
            _showError('Lütfen IMEI, IP veya Seri No girin.');
            return;
        }

        final type = _detectIdentifierType(raw);
        if (type == null) {
            _showError('Geçersiz değer. Örnekler:\n'
                '- IP: 192.168.1.10 (0–255)\n'
                '- IMEI: en fazla 15 haneli sayısal\n'
                '- Seri No: 3–32, harf/rakam/-/_ (tamamı rakam olamaz)');
            return;
        }

        try {
            final uri = Uri.parse("$_apiBaseUrl/lookup");
            final response = await http.post(
                uri,
                headers: {"Content-Type": "application/json"},
                body: jsonEncode({"identifier_type": type, "identifier": raw}),
            );

            if (response.statusCode == 200) {
                final decoded = jsonDecode(response.body);
                if (decoded["ok"] == true && decoded["data"] != null) {
                    Map<String, dynamic> fresh =
                    Map<String, dynamic>.from(decoded["data"]);

                    // Burada sadece JSON'u sakla, override etme!
                    setState(() => _finalJson = fresh);
//4-) Saniye başına sayfa geçiş hızını vermektedir.
                    _pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.ease,
                    );
                } else {
                    _showError("API’den geçerli veri gelmedi.");
                }
            } else {
                _showError("API isteği başarısız oldu: ${response.statusCode}");
            }
        } catch (e) {
            _showError("Hata oluştu: $e");
        }
    }

//5-) Aşağıda verilenler sayesinde ıp, imei ve seri no'nun özelliklerinin uyup uyulmadığı göstermekte.
    String? _detectIdentifierType(String input) {
        final v = input.trim();
        if (_isValidIP(v)) return "ip";
        if (_isValidIMEI(v)) return "imei";
        if (RegExp(r'^\d+$').hasMatch(v) && v.length > 15) return null;
        if (_isValidSerial(v)) return "serial";
        return null;
    }

    bool _isValidIP(String s) {
        final parts = s.split('.');
        if (parts.length != 4) return false;
        for (final p in parts) {
            if (p.isEmpty || !RegExp(r'^\d+$').hasMatch(p)) return false;
            final n = int.parse(p);
            if (n < 0 || n > 255) return false;
        }
        return true;
    }

    bool _isValidIMEI(String s) => RegExp(r'^\d{1,15}$').hasMatch(s);
    bool _isValidSerial(String s) =>
        RegExp(r'^(?!\d+$)[A-Za-z0-9_-]{3,32}$').hasMatch(s);

    Map<String, dynamic> _deepMerge(
        Map<String, dynamic> base, Map<String, dynamic> over) {
        final out = Map<String, dynamic>.from(base);
        over.forEach((k, v) {
            if (v is Map && out[k] is Map) {
                out[k] = _deepMerge(
                    Map<String, dynamic>.from(out[k]), Map<String, dynamic>.from(v));
            } else {
                out[k] = v;
            }
        });
        return out;
    }
//6-) Altta verilen hataları ve rengi belirler.
    void _showError(String msg) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg), backgroundColor: Colors.red),
        );
    }

    Future<void> _pickDateTime({required bool start}) async {
        final now = DateTime.now();
        final date = await showDatePicker(
            context: context,
            initialDate: now,
            firstDate: DateTime(2020),
            lastDate: DateTime(2100),
        );
        if (date == null) return;
        final time = await showTimePicker(
            context: context,
            initialTime: TimeOfDay.fromDateTime(now),
        );
        if (time == null) return;
        final dt =
        DateTime(date.year, date.month, date.day, time.hour, time.minute);
        setState(() {
            if (start) {
                _lpStart = dt;
            } else {
                _lpEnd = dt;
            }
        });
    }

    void _goBack() {
        final page = _pageController.hasClients ? _pageController.page ?? 0 : 0;
        if (page > 0) {
            _pageController.previousPage(
                duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
        }
    }

    // UI
    @override
    Widget build(BuildContext context) {
        return Scaffold(
            body: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [_buildLoginPage(), _buildDevicePage(), _buildInfoPage()],
            ),
        );
    }

    Widget _buildLoginPage() {
        return SafeArea(
            child: Center(
                child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                            // Başlık: İKOM (siyah) BİLİŞİM (mavi)
                            RichText(
                                text: const TextSpan(
                                    children: [
                                        TextSpan(
                                            text: "İKOM ",
                                            style: TextStyle(
                                                fontSize: 28,
                                                color: Colors.black,
                                                fontWeight: FontWeight.bold,
                                            ),
                                        ),
                                        TextSpan(
                                            text: "BİLİŞİM",
                                            style: TextStyle(
                                                fontSize: 28,
                                                color: Colors.blue,
                                                fontWeight: FontWeight.bold,
                                            ),
                                        ),
                                    ],
                                ),
                            ),
                            const SizedBox(height: 24),
                            _textField(_nameCtrl, "Name"),
                            const SizedBox(height: 10),
                            _textField(_passCtrl, "Password", obscure: true),
                            const SizedBox(height: 18),
                            Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                    OutlinedButton(onPressed: _goBack, child: const Text("Geri")),
                                    const SizedBox(width: 10),
                                    ElevatedButton(
                                        onPressed: () {
                                            if (_nameCtrl.text.trim().isNotEmpty &&
                                                _passCtrl.text.trim().isNotEmpty) {
                                                _pageController.nextPage(
                                                    duration: const Duration(milliseconds: 300),
                                                    curve: Curves.ease);
                                            } else {
                                                _showError("Ad ve şifre boş olamaz.");
                                            }
                                        },
                                        child: const Text("Devam"),
                                    ),
                                ],
                            ),
                            const SizedBox(height: 10),
                            TextButton(
                                onPressed: () async {
                                    final result = await Navigator.push<Map<String, String>>(
                                        context,
                                        MaterialPageRoute(
                                            builder: (_) => SettingsPage(
                                                overrides: _userOverrides?.map((k, v) => MapEntry(k, v.toString())) ?? {},
                                            ),
                                        ),
                                    );

                                    if (result != null) {
                                        setState(() {
                                            // Burada override’ları saklıyoruz
                                            _userOverrides = result;
                                        });
                                        _showError("Ayarlar kaydedildi ✅");
                                    }
                                },
                                child: const Text("⚙️ Settings"),
                            ),

                        ],
                    ),
                ),
            ),
        );
    }

    Widget _buildDevicePage() {
        return SafeArea(
            child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                        Text("Cihaz Bilgileri (API: $_apiBaseUrl)",
                            style:
                            const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 24),
                        _textField(_deviceCtrl, "IMEI / IP / Seri No"),
                        const SizedBox(height: 16),
                        Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                                ElevatedButton(
                                    onPressed: _fetchFromApi, child: const Text("API’den Getir")),
                                const SizedBox(width: 10),
                                OutlinedButton(onPressed: _goBack, child: const Text("Geri")),
                            ],
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                            onPressed: () async {
                                final ctrl = TextEditingController(text: _apiBaseUrl);
                                final newUrl = await showDialog<String>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                        title: const Text("API Değiştir"),
                                        content: TextField(
                                            controller: ctrl,
                                            decoration: const InputDecoration(
                                                labelText: "Yeni API URL",
                                                border: OutlineInputBorder(),
                                            ),
                                        ),
                                        actions: [
                                            TextButton(
                                                onPressed: () => Navigator.pop(context),
                                                child: const Text("İptal")),
                                            ElevatedButton(
                                                onPressed: () =>
                                                    Navigator.pop(context, ctrl.text.trim()),
                                                child: const Text("Kaydet")),
                                        ],
                                    ),
                                );
                                if (newUrl != null && newUrl.isNotEmpty) {
                                    setState(() => _apiBaseUrl = newUrl);
                                }
                            },
                            child: const Text("API Değiştir"),
                        ),
                    ],
                ),
            ),
        );
    }

    Widget _buildInfoPage() {
        return SafeArea(
            child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                        Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                                const Text("Information",
                                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                                Row(
                                    children: [
                                        OutlinedButton(onPressed: _goBack, child: const Text("Geri")),
                                        const SizedBox(width: 8),
                                        ElevatedButton(
                                            onPressed: () {
                                                showDialog(
                                                    context: context,
                                                    builder: (context) {
                                                        return AlertDialog(
                                                            title: const Text("Röle Kontrol"),
                                                            content: Column(
                                                                mainAxisSize: MainAxisSize.min,
                                                                children: [
                                                                    _buildRelayControl("RELAY1"),
                                                                    const SizedBox(height: 10),
                                                                    _buildRelayControl("RELAY2"),
                                                                ],
                                                            ),
                                                            actions: [
                                                                TextButton(
                                                                    onPressed: () => Navigator.pop(context),
                                                                    child: const Text("Kapat")),
                                                            ],
                                                        );
                                                    },
                                                );
                                            },
                                            child: const Text("Röle"),
                                        ),
                                    ],
                                ),
                            ],
                        ),




                        ElevatedButton(
                            onPressed: () {
                                setState(() => _showFormPanel = !_showFormPanel);
                            },
                            child: Text(_showFormPanel ? "Paneli Kapat" : "Paneli Aç"),
                        ),
                        const SizedBox(height: 10),

                        if (_showFormPanel) ...[
                            SizedBox(
                                width: 200,
                                child: DropdownButtonFormField<ReadForm>(
                                    value: _activeForm,
                                    decoration: const InputDecoration(
                                        labelText: "Okuma Tipi Seç",
                                        border: OutlineInputBorder(),
                                    ),
                                    items: const [
                                        DropdownMenuItem(
                                            value: ReadForm.readout, child: Text("Readout")),
                                        DropdownMenuItem(value: ReadForm.lp, child: Text("LP")),
                                        DropdownMenuItem(value: ReadForm.obis, child: Text("Obis")),
                                    ],
                                    onChanged: (v) {
                                        if (v != null) setState(() => _activeForm = v);
                                    },
                                ),
                            ),
                            const SizedBox(height: 12),
                            _buildSelectedForm(),
                        ],

                        const SizedBox(height: 16),

                        // API'den gelen JSON'u göster (sadece üst key isimlerini override et)
                        Expanded(
                            child: _finalJson == null
                                ? const Center(child: Text("Henüz veri yok"))
                                : ListView(
                                children: _finalJson!.entries.map((e) {
                                    // Burada sadece üst key değişiyor
                                    final displayKey = _userOverrides?[e.key] ?? e.key;
                                    final value = e.value;

                                    if (value is Map) {
                                        return ExpansionTile(
                                            title: Text(displayKey,
                                                style: const TextStyle(
                                                    fontWeight: FontWeight.bold)),
                                            children: value.entries
                                                .map((sub) => ListTile(
                                                title: Text(sub.key),          // SABİT
                                                subtitle: Text(sub.value.toString()), // SABİT
                                            ))
                                                .toList(),
                                        );
                                    } else if (value is List) {
                                        return ExpansionTile(
                                            title: Text(displayKey,
                                                style: const TextStyle(
                                                    fontWeight: FontWeight.bold)),
                                            children: value.map((item) {
                                                if (item is Map) {
                                                    return Column(
                                                        children: item.entries
                                                            .map((sub) => ListTile(
                                                            title: Text(sub.key),      // SABİT
                                                            subtitle:
                                                            Text(sub.value.toString()), // SABİT
                                                        ))
                                                            .toList(),
                                                    );
                                                } else {
                                                    return ListTile(title: Text(item.toString()));
                                                }
                                            }).toList(),
                                        );
                                    } else {
                                        return ListTile(
                                            title: Text(displayKey),
                                            subtitle: Text(value.toString()),
                                        );
                                    }
                                }).toList(),
                            ),
                        )
                    ],
                ),
            ),
        );
    }


    Widget _buildSelectedForm() {
        switch (_activeForm) {
            case ReadForm.readout:
                return _buildReadoutForm();
            case ReadForm.lp:
                return _buildLpForm();
            case ReadForm.obis:
                return _buildObisForm();
        }
    }

    Widget _buildReadoutForm() {
        return _FormCard(
            title: "Okuma Tipi: Readout",
            children: [
                _Label("Sayaç Seri No"),
                _textfield(_roSnCtrl, "Tek sayaç için boş olabilir."),
                const SizedBox(height: 10),
                _Label("Seri Port"),
                _DropdownLike(
                    value: _roPort,
                    items: const ["mxc1", "mxc2", "mxc3"],
                    onChanged: (v) => setState(() => _roPort = v),
                ),
                const SizedBox(height: 10),
                _Label("Readout Option"),
                _textfield(_roOptionsCtrl,
                    "0,6,7,8,9 0=[ACK]050[CR][LF],6=[ACK]056[CR][LF], 7=[ACK]057[CR][LF]"),
                const SizedBox(height: 10),
                _primaryButton("Sayaç Bilgilerini Getir", () async {
                    final uri = Uri.parse("$_apiBaseUrl/lookup");
                    final payload = {
                        "identifier_type": "imei",
                        "identifier": _deviceCtrl.text,
                        "read_form": "readout"
                    };

                    try {
                        final response = await http.post(
                            uri,
                            headers: {"Content-Type": "application/json"},
                            body: jsonEncode(payload),
                        );

                        if (response.statusCode == 200) {
                            final decoded = jsonDecode(response.body);
                            if (decoded["ok"] == true && decoded["data"] != null) {
                                setState(() {
                                    _finalJson = Map<String, dynamic>.from(decoded["data"]);
                                });
                            } else {
                                _showError("Sayaç bilgisi bulunamadı.");
                            }
                        } else {
                            _showError("API isteği başarısız: ${response.statusCode}");
                        }
                    } catch (e) {
                        _showError("Hata oluştu: $e");
                    }
                }),

            ],
        );
    }

    Widget _buildLpForm() {
        return _FormCard(
            title: "Okuma Tipi: LP",
            children: [
                _Label("Sayaç Seri No"),
                _textfield(_lpSnCtrl, "Tek sayaç için boş olabilir."),
                const SizedBox(height: 10),
                _Label("Seri Port"),
                _DropdownLike(
                    value: _lpPort,
                    items: const ["mxc1", "mxc2", "mxc3"],
                    onChanged: (v) => setState(() => _lpPort = v),
                ),
                const SizedBox(height: 10),
                _Label("LP Başlangıç Tarihi"),
                _DateField(
                    dateTime: _lpStart,
                    onTap: () => _pickDateTime(start: true),
                ),
                const SizedBox(height: 10),
                _Label("LP Bitiş Tarihi"),
                _DateField(
                    dateTime: _lpEnd,
                    onTap: () => _pickDateTime(start: false),
                ),
                const SizedBox(height: 10),
                _primaryButton("Sayaç Bilgilerini Getir", () {
                    _showError("LP form örnek düğmesi (demo).");
                }),
            ],
        );
    }

    Widget _buildObisForm() {
        return _FormCard(
            title: "Okuma Tipi: Obis",
            children: [
                _Label("Sayaç Seri No"),
                _textfield(_obSnCtrl, "Tek sayaç için boş olabilir."),
                const SizedBox(height: 10),
                _Label("Seri Port"),
                _DropdownLike(
                    value: _obPort,
                    items: const ["mxc1", "mxc2", "mxc3"],
                    onChanged: (v) => setState(() => _obPort = v),
                ),
                const SizedBox(height: 10),
                _Label("Obis Listesi"),
                _textfield(_obListCtrl, "1.8.0,32.7.0"),
                const SizedBox(height: 10),
                _primaryButton("Sayaç Bilgilerini Getir", () {

                    _showError("Obis form örnek düğmesi ,demo.");
                }),
            ],
        );
    }

    // Basit input helper’ları
    Widget _textField(TextEditingController c, String hint,
        {bool obscure = false}) {
        return TextField(
            controller: c,
            obscureText: obscure,
            decoration: InputDecoration(
                border: const OutlineInputBorder(),
                labelText: hint,
            ),
        );
    }

    Widget _textfield(TextEditingController c, String hint) {
        return TextField(
            controller: c,
            decoration: InputDecoration(
                hintText: hint,
                border: const OutlineInputBorder(),
            ),
        );
    }
}



class _FormCard extends StatelessWidget {
    final String title;
    final List<Widget> children;
    const _FormCard({required this.title, required this.children});

    @override
    Widget build(BuildContext context) {
        return Card(
            elevation: 0,
            color:  Colors.lightBlue,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                    title: Text(title,
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold)),
                    children: children
                        .map((w) => Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        child: DefaultTextStyle.merge(
                            style: const TextStyle(color: Colors.white),
                            child: w,
                        ),
                    ))
                        .toList(),
                ),
            ),
        );
    }
}


class _Label extends StatelessWidget {
    final String text;
    const _Label(this.text);
    @override
    Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child:
        Text(text, style: const TextStyle(fontWeight: FontWeight.bold)),
    );
}

class _DropdownLike extends StatelessWidget {
    final String value;
    final List<String> items;
    final ValueChanged<String> onChanged;
    const _DropdownLike(
        {required this.value, required this.items, required this.onChanged});

    @override
    Widget build(BuildContext context) {
        return DropdownButtonFormField<String>(
            value: value,
            items: items
                .map((e) => DropdownMenuItem<String>(value: e, child: Text(e)))
                .toList(),
            onChanged: (v) {
                if (v != null) onChanged(v);
            },
            decoration: const InputDecoration(
                border: OutlineInputBorder(),
            ),
        );
    }
}

class _DateField extends StatelessWidget {
    final DateTime? dateTime;
    final VoidCallback onTap;
    const _DateField({required this.dateTime, required this.onTap});

    @override
    Widget build(BuildContext context) {
        final text = dateTime == null
            ? "gg.aa.yyyy --:--"
            : "${dateTime!.day.toString().padLeft(2, '0')}."
            "${dateTime!.month.toString().padLeft(2, '0')}."
            "${dateTime!.year} "
            "${dateTime!.hour.toString().padLeft(2, '0')}:"
            "${dateTime!.minute.toString().padLeft(2, '0')}";
        return InkWell(
            onTap: onTap,
            child: InputDecorator(
                decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                ),
                child: Row(
                    children: [
                        Expanded(child: Text(text)),
                        const Icon(Icons.calendar_today, size: 18),
                    ],
                ),
            ),
        );
    }
}

Widget _primaryButton(String text, VoidCallback onPressed) {
    return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
            onPressed: onPressed,
            child: Text(text),
        ),
    );
}
class SettingsPage extends StatefulWidget {
    final Map<String, String> overrides;
    const SettingsPage({super.key, required this.overrides});

    @override
    State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
    late Map<String, TextEditingController> _controllers;

    @override
    void initState() {
        super.initState();
        // Varsayılan keyler ve mevcut override değerlerini doldur
        final keys = ["comm", "information", "io", "read_rate", "recieve_time"];
        _controllers = {
            for (var k in keys)
                k: TextEditingController(text: widget.overrides[k] ?? k)
        };
    }

    @override
    Widget build(BuildContext context) {
        return Scaffold(
            appBar: AppBar(title: const Text("Settings")),
            body: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                    children: [
                        Expanded(
                            child: ListView(
                                children: _controllers.entries.map((entry) {
                                    return Padding(
                                        padding: const EdgeInsets.only(bottom: 12),
                                        child: TextField(
                                            controller: entry.value,
                                            decoration: InputDecoration(
                                                labelText: "Rename ${entry.key}",
                                                border: const OutlineInputBorder(),
                                            ),
                                        ),
                                    );
                                }).toList(),
                            ),
                        ),
                        ElevatedButton(
                            onPressed: () {
                                // Yeni key isimlerini dön
                                final result = {
                                    for (var e in _controllers.entries) e.key: e.value.text
                                };
                                Navigator.pop(context, result);
                            },
                            child: const Text("Kaydet"),
                        )
                    ],
                ),
            ),
        );
    }
}
Widget _buildRelayControl(String relayName) {
    bool isOn = false;

    return StatefulBuilder(
        builder: (context, setState) {
            return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                    Text(relayName),
                    Switch(
                        value: isOn,
                        onChanged: (val) {
                            setState(() => isOn = val);
                            // Burada API çağrısı yapılabilir (örnek):
                            // http.post(Uri.parse("$_apiBaseUrl/relay"),
                            //   body: jsonEncode({"relay": relayName, "state": val ? "on" : "off"}));
                        },
                    ),
                ],
            );
        },
    );
}
