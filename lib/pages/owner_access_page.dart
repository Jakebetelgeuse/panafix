import 'package:flutter/material.dart';

import 'owner_home_page.dart';

class OwnerAccessPage extends StatefulWidget {
  const OwnerAccessPage({super.key});

  @override
  State<OwnerAccessPage> createState() => _OwnerAccessPageState();
}

class _OwnerAccessPageState extends State<OwnerAccessPage> {
  static const String _ownerKey = '1adhara1.,';

  final TextEditingController _keyController = TextEditingController();
  bool _isChecking = false;

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _unlockOwnerPanel() async {
    final key = _keyController.text.trim();

    if (key.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escribe tu clave de duena.')),
      );
      return;
    }

    setState(() {
      _isChecking = true;
    });

    await Future<void>.delayed(const Duration(milliseconds: 250));

    if (!mounted) return;

    if (key != _ownerKey) {
      setState(() {
        _isChecking = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Clave incorrecta.')),
      );
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const OwnerHomePage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF111827),
                          Color(0xFF1F2937),
                          Color(0xFFDC2626),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Acceso privado',
                          style: TextStyle(
                            color: Color(0xFFFECACA),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 10),
                        Text(
                          'Escribe tu clave de duena para entrar al panel privado de control.',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            height: 1.15,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: _keyController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Clave de duena',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                    onSubmitted: (_) => _unlockOwnerPanel(),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isChecking ? null : _unlockOwnerPanel,
                      icon: const Icon(Icons.admin_panel_settings_outlined),
                      label: Text(
                        _isChecking ? 'Verificando...' : 'Entrar al panel',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
