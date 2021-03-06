import 'dart:async';
import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:myanilab/Core/Providers/token_provider.dart';
import 'package:myanilab/Core/Utils/mal_exceptions.dart';
import 'package:myanilab/UI/Views/home_view.dart';
import 'package:myanilab/UI/Views/profile_view.dart';
import 'package:myanilab/UI/Views/login_view.dart';
import 'package:myanilab/UI/Views/seasonal_anime_view.dart';
import 'package:myanilab/UI/Views/top_anime_view.dart';
import 'package:myanilab/UI/Widgets/loading_scaffold.dart';
import 'package:myanilab/UI/Widgets/mal_drawer.dart';
import 'package:provider/provider.dart';
import 'package:uni_links/uni_links.dart';
import 'package:url_launcher/url_launcher.dart';

class Root extends StatefulWidget {
  const Root({Key? key}) : super(key: key);

  @override
  State<Root> createState() => _RootState();
}

class _RootState extends State<Root> {
  bool initUriHandled = false;
  StreamSubscription? subscription;

  @override
  void initState() {
    super.initState();
    handleIncomingLinks();
    handleInitialUri();
  }

  @override
  void dispose() {
    subscription?.cancel();
    super.dispose();
  }

  void handleIncomingLinks() {
    if (!kIsWeb) {
      subscription = uriLinkStream.listen(
        (uri) {
          if (!mounted) return;
          if (uri != null) {
            final code = uri.queryParameters['code'];
            final state = uri.queryParameters['state'];
            if (code != null && state != null) {
              final l = Uri.decodeComponent(state);
              handleAuth(code, l);
            }
          }
        },
        onError: (Object err) {
          if (!mounted) return;
          log('got err: $err');
        },
      );
    }
  }

  Future<void> handleInitialUri() async {
    if (!initUriHandled) {
      initUriHandled = true;
      try {
        final uri = await getInitialUri();
        if (!mounted) return;
        if (uri != null) {
          final code = uri.queryParameters['code'];
          final state = uri.queryParameters['state'];
          if (code != null && state != null) {
            final l = Uri.decodeComponent(state);
            handleAuth(code, l);
          }
        }
      } on PlatformException {
        log('falied to get initial uri');
      } on FormatException catch (_) {
        if (!mounted) return;
        log('malformed initial uri');
      }
    }
  }

  handleAuth(String code, String state) async {
    closeWebView();
    try {
      await Provider.of<TokenProvider>(context, listen: false).getToken(code);
    } on MalException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const MalDrawer(),
      body: Consumer<ValueNotifier<int>>(
        builder: (_, activePage, __) => Consumer<TokenProvider>(
          builder: (_, tokenProvider, __) {
            if (tokenProvider.isLoading) {
              return LoadingScaffold(
                title: MalDrawer.items.keys.toList()[activePage.value],
              );
            }
            return IndexedStack(
              index: activePage.value,
              children: [
                const HomeView(),
                const TopAnimeView(),
                const SeasonalAnimeView(),
                tokenProvider.token == null
                    ? const LoginView(title: 'Profile')
                    : const ProfileView(),
              ],
            );
          },
        ),
      ),
    );
  }
}
