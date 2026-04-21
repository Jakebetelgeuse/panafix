import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'auth_service.dart';
import 'register_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final AuthService authService = AuthService();

  bool isLoading = false;
  bool isGoogleLoading = false;
  bool isFacebookLoading = false;
  bool obscurePassword = true;
  int _logoTapCount = 0;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> login() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completa todos los campos.')),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      String message = 'No se pudo iniciar sesion.';

      if (e.code == 'user-not-found') {
        message = 'Ese correo no existe.';
      } else if (e.code == 'wrong-password' ||
          e.code == 'invalid-credential') {
        message = 'Correo o contrasena incorrectos.';
      } else if (e.code == 'invalid-email') {
        message = 'El correo no es valido.';
      } else if (e.code == 'network-request-failed') {
        message = 'Revisa tu conexion e intenta otra vez.';
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error inesperado: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> loginWithGoogle() async {
    setState(() {
      isGoogleLoading = true;
    });

    try {
      await authService.signInWithGoogle();
    } on FirebaseAuthException catch (e) {
      String message = 'No se pudo iniciar con Google.';

      if (e.code == 'popup-closed-by-user') {
        message = 'Cerraste la ventana de Google.';
      } else if (e.code == 'network-request-failed') {
        message = 'Revisa tu conexion e intenta otra vez.';
      } else if (e.code == 'account-exists-with-different-credential') {
        message = 'Ese correo ya existe con otro metodo.';
      } else if (e.code == 'google-sign-in-cancelled') {
        message = 'Cancelaste el inicio con Google.';
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error con Google: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          isGoogleLoading = false;
        });
      }
    }
  }

  Future<void> loginWithFacebook() async {
    setState(() {
      isFacebookLoading = true;
    });

    try {
      await authService.signInWithFacebook();
    } on FirebaseAuthException catch (e) {
      String message = 'No se pudo iniciar con Facebook.';

      if (e.code == 'facebook-sign-in-cancelled') {
        message = 'Cancelaste el inicio con Facebook.';
      } else if (e.code == 'account-exists-with-different-credential') {
        message = 'Ese correo ya existe con otro metodo.';
      } else if (e.code == 'popup-closed-by-user') {
        message = 'Cerraste la ventana de Facebook.';
      } else if (e.code == 'network-request-failed') {
        message = 'Revisa tu conexion e intenta otra vez.';
      } else if (e.message != null && e.message!.isNotEmpty) {
        message = e.message!;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error con Facebook: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          isFacebookLoading = false;
        });
      }
    }
  }

  Future<void> resetPassword() async {
    final email = emailController.text.trim();

    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa tu correo primero.')),
      );
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Te enviamos un correo para recuperar tu cuenta. Revisa tambien spam o promociones.',
          ),
        ),
      );
    } on FirebaseAuthException catch (e) {
      String message = 'No se pudo enviar el correo.';

      if (e.code == 'user-not-found') {
        message = 'Ese correo no esta registrado.';
      } else if (e.code == 'invalid-email') {
        message = 'El correo no es valido.';
      } else if (e.code == 'network-request-failed') {
        message = 'Revisa tu conexion e intenta otra vez.';
      } else if (e.code == 'too-many-requests') {
        message =
            'Hiciste demasiados intentos. Espera un poco antes de volver a probar.';
      } else if (e.code == 'invalid-continue-uri') {
        message = 'Firebase necesita revisar la configuracion del enlace.';
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error inesperado: $e')),
      );
    }
  }

  void _handleLogoTap() {
    setState(() {
      _logoTapCount++;
    });

    if (_logoTapCount >= 5) {
      _logoTapCount = 0;
      showDialog<void>(
        context: context,
        builder: (context) => Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF1B130C),
                  Color(0xFF3B1F10),
                  Color(0xFF6A2F12),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: const Color(0xFFFFD8B0).withOpacity(0.22),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.28),
                  blurRadius: 28,
                  offset: const Offset(0, 18),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0x33FFB7D5),
                        Color(0x22FFD9E8),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0x44FFB7D5),
                    ),
                  ),
                  child: const Icon(
                    Icons.favorite_rounded,
                    color: Color(0xFFFFA7C8),
                    size: 30,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Para Felipe',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFFFFC9DD),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.6,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Todo esto es para ti,\npor siempre.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFFFF9FC2),
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'En cada detalle de este proyecto,\nsiempre estas tu. Te amo.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFFFFE2EC),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    height: 1.65,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 20),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Cerrar',
                    style: TextStyle(
                      color: Color(0xFFFFD8B0),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final buttonsDisabled = isLoading || isGoogleLoading || isFacebookLoading;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFF6F4EF),
              Color(0xFFFFF0DE),
              Color(0xFFFFD39E),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1B130C),
                        borderRadius: BorderRadius.circular(36),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          MouseRegion(
                            cursor: SystemMouseCursors.basic,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: _handleLogoTap,
                              child: const _SecretLogoMark(),
                            ),
                          ),
                          const SizedBox(height: 22),
                          const Text(
                            'Panafix',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 34,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Servicios del hogar con seguimiento, pago retenido y soporte directo.',
                            style: TextStyle(
                              color: Color(0xFFD9D2CB),
                              fontSize: 15,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 18),
                          const Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              _InfoBadge(label: 'Tecnicos verificados'),
                              _InfoBadge(label: 'Pago protegido'),
                              _InfoBadge(label: 'Soporte rapido'),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(32),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 24,
                            offset: const Offset(0, 16),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Inicia sesion',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Entra a tu cuenta para pedir, gestionar o atender servicios.',
                            style: TextStyle(
                              color: Color(0xFF756B61),
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 22),
                          TextField(
                            controller: emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: 'Correo',
                              prefixIcon: Icon(Icons.mail_outline),
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: passwordController,
                            obscureText: obscurePassword,
                            decoration: InputDecoration(
                              labelText: 'Contrasena',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                onPressed: () {
                                  setState(() {
                                    obscurePassword = !obscurePassword;
                                  });
                                },
                                icon: Icon(
                                  obscurePassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: buttonsDisabled ? null : resetPassword,
                              child: const Text('Recuperar contrasena'),
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: buttonsDisabled ? null : login,
                              child: Text(
                                isLoading ? 'Entrando...' : 'Iniciar sesion',
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed:
                                  buttonsDisabled ? null : loginWithGoogle,
                              icon: isGoogleLoading
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.login),
                              label: Text(
                                isGoogleLoading
                                    ? 'Conectando...'
                                    : 'Continuar con Google',
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed:
                                  buttonsDisabled ? null : loginWithFacebook,
                              icon: isFacebookLoading
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.facebook),
                              label: Text(
                                isFacebookLoading
                                    ? 'Conectando...'
                                    : 'Continuar con Facebook',
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: TextButton(
                              onPressed: buttonsDisabled
                                  ? null
                                  : () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => const RegisterPage(),
                                        ),
                                      );
                                    },
                              child: const Text('Crear cuenta nueva'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoBadge extends StatelessWidget {
  final String label;

  const _InfoBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Colors.white.withOpacity(0.16),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _SecretLogoMark extends StatelessWidget {
  const _SecretLogoMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: const Color(0xFFFF8A1F),
        borderRadius: BorderRadius.circular(22),
      ),
      child: const Icon(
        Icons.home_repair_service,
        color: Colors.white,
        size: 34,
      ),
    );
  }
}
