import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../utils/error_text.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();

  bool _isLogin = true;
  bool _loading = false;
  String _error = '';

  Future<void> _submit() async {
    setState(() { _loading = true; _error = ''; });
    try {
      if (_isLogin) {
        await _authService.login(
          _emailController.text.trim(),
          _passwordController.text.trim(),
        );
      } else {
        await _authService.register(
          _nameController.text,
          _emailController.text.trim(),
          _passwordController.text.trim(),
        );
      }
      // Dál se nikam nenaviguje – RootGate po přihlášení sám přepne na
      // další obrazovku díky streamu authStateChanges.
    } catch (e) {
      if (mounted) {
        setState(() => _error = errorText(e));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _googleSignIn() async {
    setState(() { _loading = true; _error = ''; });
    try {
      await _authService.signInWithGoogle();
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.indigo.shade50,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.sports, size: 80, color: Colors.indigo),
              const SizedBox(height: 16),
              const Text('TrenApp',
                  style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.indigo)),
              const SizedBox(height: 32),
              if (!_isLogin) ...[
                TextField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Jméno',
                    hintText: 'např. Jan Novák',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Heslo',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
              ),
              if (_error.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(_error, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 24),
              _loading
                  ? const CircularProgressIndicator()
                  : Column(
                      children: [
                        ElevatedButton(
                          onPressed: _submit,
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 50),
                            backgroundColor: Colors.indigo,
                            foregroundColor: Colors.white,
                          ),
                          child: Text(_isLogin ? 'Přihlásit se' : 'Registrovat'),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _googleSignIn,
                          icon: const Icon(Icons.g_mobiledata, size: 28),
                          label: const Text('Přihlásit přes Google'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 50),
                          ),
                        ),
                      ],
                    ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => setState(() => _isLogin = !_isLogin),
                child: Text(_isLogin
                    ? 'Nemáš účet? Zaregistruj se'
                    : 'Máš účet? Přihlas se'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}