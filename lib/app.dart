import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/theme.dart';
import 'cubit/auth_cubit.dart';
import 'cubit/companies_cubit.dart';
import 'data/auth_repository.dart';
import 'data/companies_repository.dart';
import 'screens/companies_list_screen.dart';
import 'screens/login_screen.dart';

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<AuthRepository>(create: (_) => AuthRepository()),
        RepositoryProvider<CompaniesRepository>(
          create: (_) => CompaniesRepository(),
        ),
      ],
      child: BlocProvider<AuthCubit>(
        create: (context) =>
            AuthCubit(authRepository: context.read<AuthRepository>()),
        child: MaterialApp(
          title: 'إدارة الشركات',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          locale: const Locale('ar'),
          supportedLocales: const [Locale('ar')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (context, child) {
            return Directionality(
              textDirection: TextDirection.rtl,
              child: child!,
            );
          },
          home: const _AuthGate(),
        ),
      ),
    );
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, state) {
        switch (state.status) {
          case AuthStatus.unknown:
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          case AuthStatus.unauthenticated:
            return const LoginScreen();
          case AuthStatus.authenticated:
            return BlocProvider<CompaniesCubit>(
              create: (context) => CompaniesCubit(
                companiesRepository: context.read<CompaniesRepository>(),
              ),
              child: const CompaniesListScreen(),
            );
        }
      },
    );
  }
}
