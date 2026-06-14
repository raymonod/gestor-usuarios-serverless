import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/user.dart';
import 'login_screen.dart';
import 'users_screen.dart';
import 'notification_screen.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _api = ApiService();
  User? _currentUser;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

Future<void> _loadProfile() async {
  setState(() {
    _loading = true;
    _error = null;
  });

  try {
    final prefs = await SharedPreferences.getInstance();

    final userJson = prefs.getString('current_user');

    if (userJson != null) {
      final userMap = jsonDecode(userJson);

      if (mounted) {
        setState(() {
          _currentUser = User.fromJson(userMap);
        });
      }
    }
  } catch (e) {
    if (mounted) {
      setState(() {
        _error = e.toString();
      });
    }
  } finally {
    if (mounted) {
      setState(() {
        _loading = false;
      });
    }
  }
}

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Estás seguro de que deseas cerrar sesión?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Cerrar sesión')),
        ],
      ),
    );
    if (confirmed == true) {
      await _api.logout();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel principal'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesión',
            onPressed: _logout,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadProfile,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Tarjeta de bienvenida
            Card(
              elevation: 0,
              color: theme.colorScheme.primaryContainer,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: _loading
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    : _error != null
                        ? Column(
                            children: [
                              Icon(Icons.error_outline,
                                  color: theme.colorScheme.error, size: 32),
                              const SizedBox(height: 8),
                              Text(_error!,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      color: theme.colorScheme.error)),
                              TextButton(
                                  onPressed: _loadProfile,
                                  child: const Text('Reintentar')),
                            ],
                          )
                        : Row(
                            children: [
                              CircleAvatar(
                                radius: 28,
                                backgroundColor:
                                    theme.colorScheme.primary,
                                child: Text(
                                  _currentUser?.name
                                          .substring(0, 1)
                                          .toUpperCase() ??
                                      '?',
                                  style: TextStyle(
                                      fontSize: 24,
                                      color: theme.colorScheme.onPrimary,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Hola, ${_currentUser?.name ?? 'Usuario'}!',
                                      style: theme.textTheme.titleLarge
                                          ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: theme.colorScheme
                                                  .onPrimaryContainer),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _currentUser?.email ?? '',
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                              color: theme.colorScheme
                                                  .onPrimaryContainer
                                                  .withValues(alpha: 0.75)),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
              ),
            ),
            const SizedBox(height: 24),

            Text('Acciones rápidas',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),

            // Gestionar usuarios
            _ActionTile(
              icon: Icons.group_outlined,
              title: 'Gestionar usuarios',
              subtitle: 'Ver, editar y eliminar usuarios',
              color: theme.colorScheme.secondaryContainer,
              iconColor: theme.colorScheme.secondary,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const UsersScreen()),
              ).then((_) => _loadProfile()),
            ),
            const SizedBox(height: 12),

            _ActionTile(
              icon: Icons.email_outlined,
              title: 'Enviar Notificación',
              subtitle: 'Enviar correo mediante SNS',
              color: theme.colorScheme.primaryContainer,
              iconColor: theme.colorScheme.primary,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const NotificationScreen(),
                ),
              ),
            ),

            const SizedBox(height: 12),
            // Estado del API
            _ActionTile(
              icon: Icons.api_outlined,
              title: 'Estado del API',
              subtitle: 'Conectado al API REST en Go',
              color: theme.colorScheme.tertiaryContainer,
              iconColor: theme.colorScheme.tertiary,
              onTap: () => _showApiInfo(context),
            ),
          ],
        ),
      ),
    );
  }

  void _showApiInfo(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Información del API',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            const _InfoRow(label: 'Framework', value: 'Go + Gin'),
            const _InfoRow(label: 'Base de datos', value: 'PostgreSQL (Supabase) + GORM'),
            const _InfoRow(label: 'Autenticación', value: 'JWT (Bearer)'),
            const _InfoRow(label: 'Arquitectura', value: 'Hexagonal'),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final Color iconColor;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: color,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor),
        ),
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
              width: 130,
              child: Text(label,
                  style: const TextStyle(fontWeight: FontWeight.w500))),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
