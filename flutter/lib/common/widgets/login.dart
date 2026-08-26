import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hbb/common/hbbs/hbbs.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:flutter_hbb/models/user_model.dart';
import 'package:get/get.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../common.dart';
import './dialog.dart';
import './oidc_auth_status.dart';
import 'package:flutter_hbb/utils/http_service.dart' as http;

const kOpSvgList = [
  'github',
  'gitlab',
  'google',
  'apple',
  'okta',
  'facebook',
  'azure',
  'auth0',
  'microsoft',
  'abt',
  'abtdesk',
  'herofis',
  'pencad',
  'glasscad',
  'camcad',
];
const _requestingAccountAuth = 'Requesting account auth';
const _waitingAccountAuth = 'Waiting account auth';

class _OidcProviderBranding {
  final String label;
  final String iconKey;

  const _OidcProviderBranding({
    required this.label,
    required this.iconKey,
  });
}

_OidcProviderBranding _oidcProviderBranding(String op) {
  switch (op.toLowerCase()) {
    case 'azure':
      return _OidcProviderBranding(
        label: 'Microsoft',
        iconKey: 'microsoft',
      );
    case 'abt':
    case 'abt-sso':
    case 'abtdesk':
      return _OidcProviderBranding(
        label: 'ABT',
        iconKey: 'abt',
      );
    case 'herofis':
      return _OidcProviderBranding(
        label: 'Herofis',
        iconKey: 'herofis',
      );
    case 'pencad':
      return _OidcProviderBranding(
        label: 'PenCAD',
        iconKey: 'pencad',
      );
    case 'glasscad':
    case 'camcad':
      return _OidcProviderBranding(
        label: 'GlassCAD',
        iconKey: 'glasscad',
      );
    default:
      return _OidcProviderBranding(
        label: {
              'github': 'GitHub',
              'gitlab': 'GitLab',
              'abt': 'ABT',
              'herofis': 'Herofis',
              'pencad': 'PenCAD',
              'glasscad': 'GlassCAD',
            }[op.toLowerCase()] ??
            toCapitalized(op),
        iconKey: op.toLowerCase(),
      );
  }
}

class _IconOP extends StatelessWidget {
  final String op;
  final String? icon;
  final EdgeInsets margin;
  const _IconOP(
      {Key? key,
      required this.op,
      required this.icon,
      this.margin = const EdgeInsets.symmetric(horizontal: 4.0)})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final lowerOp = op.toLowerCase();
    if (lowerOp == 'abt' || lowerOp == 'abtdesk') {
      return Container(
        margin: margin,
        child: icon == null
            ? Image.asset(
                'assets/abt.png',
                width: 20,
                height: 20,
                errorBuilder: (_, __, ___) => SvgPicture.asset(
                  'assets/auth-abt.svg',
                  width: 20,
                  height: 20,
                ),
              )
            : SvgPicture.string(
                icon!,
                width: 20,
                height: 20,
              ),
      );
    }
    if (lowerOp == 'herofis') {
      return Container(
        margin: margin,
        child: icon == null
            ? SvgPicture.asset(
                'assets/auth-herofis.svg',
                width: 20,
                height: 20,
              )
            : SvgPicture.string(
                icon!,
                width: 20,
                height: 20,
              ),
      );
    }
    if (lowerOp == 'pencad') {
      return Container(
        margin: margin,
        child: icon == null
            ? SvgPicture.asset(
                'assets/auth-pencad.svg',
                width: 20,
                height: 20,
              )
            : SvgPicture.string(
                icon!,
                width: 20,
                height: 20,
              ),
      );
    }
    if (lowerOp == 'glasscad' || lowerOp == 'camcad') {
      return Container(
        margin: margin,
        child: icon == null
            ? SvgPicture.asset(
                'assets/auth-glasscad.svg',
                width: 20,
                height: 20,
              )
            : SvgPicture.string(
                icon!,
                width: 20,
                height: 20,
              ),
      );
    }
    final svgFile =
        kOpSvgList.contains(lowerOp) ? lowerOp : 'default';
    return Container(
      margin: margin,
      child: icon == null
          ? SvgPicture.asset(
              'assets/auth-$svgFile.svg',
              width: 20,
            )
          : SvgPicture.string(
              icon!,
              width: 20,
            ),
    );
  }
}

class ButtonOP extends StatelessWidget {
  final String op;
  final RxString curOP;
  final String? icon;
  final Color primaryColor;
  final double height;
  final Function() onTap;
  final bool Function() canStartAuth;

  const ButtonOP({
    Key? key,
    required this.op,
    required this.curOP,
    required this.icon,
    required this.primaryColor,
    required this.height,
    required this.onTap,
    required this.canStartAuth,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final branding = _oidcProviderBranding(op);
    final buttonLabel = translate("Continue with {${branding.label}}");
    return Row(children: [
      Container(
        height: height,
        width: 200,
        child: Obx(() => ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
            ).copyWith(elevation: ButtonStyleButton.allOrNull(0.0)),
            onPressed:
                curOP.value == 'rustdesk' || !canStartAuth() ? null : onTap,
            child: Row(
              children: [
                SizedBox(
                  width: 30,
                  child: _IconOP(
                    op: branding.iconKey,
                    icon: icon,
                    margin: EdgeInsets.only(right: 5),
                  ),
                ),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Center(child: Text(buttonLabel)),
                  ),
                ),
              ],
            ))),
      ),
    ]);
  }
}

class ConfigOP {
  final String op;
  final String? icon;
  ConfigOP({required this.op, required this.icon});
}

class _OidcAuthController {
  final RxString curOP = ''.obs;
  Future<void> _pendingOperation = Future<void>.value();
  int _authAttempt = 0;
  bool _closed = false;
  final _cancelInProgress = false.obs;

  bool _isCurrent(int authAttempt, String op) {
    return !_closed && authAttempt == _authAttempt && curOP.value == op;
  }

  Future<bool> start(String op) {
    if (!canStart()) {
      return Future<bool>.value(false);
    }
    final authAttempt = ++_authAttempt;
    curOP.value = op;
    // Web auth must start during the original user gesture so popups are allowed.
    if (isWeb) {
      return _startWeb(authAttempt, op);
    }
    final completer = Completer<bool>();
    _pendingOperation = _pendingOperation.then((_) async {
      if (!_isCurrent(authAttempt, op)) {
        completer.complete(false);
        return;
      }
      try {
        await bind.mainAccountAuthCancel();
        if (!_isCurrent(authAttempt, op)) {
          completer.complete(false);
          return;
        }
        await bind.mainAccountAuth(op: op, rememberMe: true);
        completer.complete(_isCurrent(authAttempt, op));
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  Future<bool> _startWeb(int authAttempt, String op) async {
    await bind.mainAccountAuth(op: op, rememberMe: true);
    return _isCurrent(authAttempt, op);
  }

  bool canStart() {
    return !_closed && !_cancelInProgress.value;
  }

  Future<bool> cancelCurrent(String op) {
    if (!canStart() || curOP.value != op) {
      return Future<bool>.value(false);
    }
    final authAttempt = ++_authAttempt;
    final completer = Completer<bool>();
    _cancelInProgress.value = true;
    _pendingOperation = _pendingOperation.then((_) async {
      try {
        await bind.mainAccountAuthCancel();
        completer.complete(_isCurrent(authAttempt, op));
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      } finally {
        _cancelInProgress.value = false;
      }
    });
    return completer.future;
  }

  Future<void> _cancelBackend() async {
    try {
      await bind.mainAccountAuthCancel();
    } catch (error, stackTrace) {
      debugPrint('Failed to cancel account authentication $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> close() async {
    if (_closed) {
      return;
    }
    final hasActiveOidcAuth =
        curOP.value.isNotEmpty && curOP.value != 'rustdesk';
    _closed = true;
    _authAttempt++;
    curOP.value = '';
    if (hasActiveOidcAuth) {
      await _cancelBackend();
    }
    await _pendingOperation;
    if (hasActiveOidcAuth) {
      await _cancelBackend();
    }
  }
}

class WidgetOP extends StatefulWidget {
  final ConfigOP config;
  final RxString curOP;
  final Function(Map<String, dynamic>) cbLogin;
  final Future<bool> Function(String) startAuth;
  final Future<bool> Function(String) cancelAuth;
  final bool Function() canStartAuth;
  const WidgetOP({
    Key? key,
    required this.config,
    required this.curOP,
    required this.cbLogin,
    required this.startAuth,
    required this.cancelAuth,
    required this.canStartAuth,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return _WidgetOPState();
  }
}

class _WidgetOPState extends State<WidgetOP> {
  Timer? _updateTimer;
  bool _isAuthStatusQueryInFlight = false;
  int _authAttempt = 0;
  String _stateMsg = '';
  String _failedMsg = '';
  String _url = '';

  @override
  void dispose() {
    super.dispose();
    _updateTimer?.cancel();
  }

  _beginQueryState(int authAttempt) {
    _updateTimer?.cancel();
    unawaited(_runAuthStatusQuery(() => _updateState(authAttempt)));
    _updateTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      unawaited(_runAuthStatusQuery(() => _updateState(authAttempt)));
    });
  }

  Future<void> _runAuthStatusQuery(Future<void> Function() query) async {
    if (_isAuthStatusQueryInFlight) {
      return;
    }
    _isAuthStatusQueryInFlight = true;
    try {
      await query();
    } finally {
      _isAuthStatusQueryInFlight = false;
    }
  }

  Future<void> _launchAuthUrl(String url) async {
    try {
      final launched = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        debugPrint('Failed to open OIDC authentication URL');
      }
    } catch (error, stackTrace) {
      debugPrint(
          'Failed to open OIDC authentication URL (${error.runtimeType})');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _copyAuthUrl(String url) async {
    try {
      await Clipboard.setData(ClipboardData(text: url));
      showToast(
        translate('Copied'),
      );
    } catch (error, stackTrace) {
      debugPrint(
          'Failed to copy OIDC authentication URL (${error.runtimeType})');
      debugPrintStack(stackTrace: stackTrace);
      showToast(translate('Failed'));
    }
  }

  void _runCurrentAuthUrlAction(
    int authAttempt,
    String authUrl,
    Future<void> Function(String) action,
  ) {
    if (!mounted ||
        authAttempt != _authAttempt ||
        widget.curOP.value != widget.config.op ||
        authUrl.isEmpty ||
        _url != authUrl) {
      return;
    }
    unawaited(action(authUrl));
  }

  void _invalidateAuthAttempt() {
    _authAttempt++;
    _url = '';
  }

  bool _isCurrentAuthAttempt(int authAttempt) {
    return mounted &&
        authAttempt == _authAttempt &&
        widget.curOP.value == widget.config.op;
  }

  Future<void> _handleAuthFailure(
    int authAttempt,
    Object error,
    String operation,
  ) async {
    debugPrint('Failed to $operation $error');
    if (!_isCurrentAuthAttempt(authAttempt)) {
      return;
    }
    _updateTimer?.cancel();
    setState(() => _failedMsg = 'Failed');
    try {
      final canceled = await widget.cancelAuth(widget.config.op);
      if (!canceled || !_isCurrentAuthAttempt(authAttempt)) {
        return;
      }
    } catch (cancelError, stackTrace) {
      debugPrint('Failed to cancel account authentication $cancelError');
      debugPrintStack(stackTrace: stackTrace);
      return;
    }
    setState(() {
      _invalidateAuthAttempt();
      widget.curOP.value = '';
    });
  }

  Future<void> _updateState(int authAttempt) {
    if (!mounted ||
        authAttempt != _authAttempt ||
        widget.curOP.value != widget.config.op) {
      _updateTimer?.cancel();
      return Future<void>.value();
    }
    return bind.mainAccountAuthResult().then<void>((result) {
      if (!mounted ||
          authAttempt != _authAttempt ||
          widget.curOP.value != widget.config.op ||
          result.isEmpty) {
        return;
      }
      final resultMap = jsonDecode(result);
      if (resultMap == null) {
        return;
      }
      final String backendStateMsg = resultMap['state_msg'];
      String failedMsg = resultMap['failed_msg'];
      final String? url = resultMap['url'];
      final stateMsg = backendStateMsg == _requestingAccountAuth &&
              (url == null || url.isEmpty)
          ? _waitingAccountAuth
          : backendStateMsg;
      final bool urlLaunched = (resultMap['url_launched'] as bool?) ?? false;
      final authBody = resultMap['auth_body'];
      if (authBody != null) {
        _updateTimer?.cancel();
        _invalidateAuthAttempt();
        widget.curOP.value = '';
        widget.cbLogin(authBody as Map<String, dynamic>);
        return;
      }
      final stateChanged = _stateMsg != stateMsg || _failedMsg != failedMsg;
      final newUrl = _url.isEmpty && url != null && url.isNotEmpty ? url : null;
      if (!stateChanged && newUrl == null) {
        return;
      }
      setState(() {
        _stateMsg = stateMsg;
        _failedMsg = failedMsg;
        if (newUrl != null) {
          _url = newUrl;
        }
        if (failedMsg.isNotEmpty) {
          _invalidateAuthAttempt();
          widget.curOP.value = '';
          _updateTimer?.cancel();
        }
      });
      if (newUrl != null && failedMsg.isEmpty && !urlLaunched) {
        unawaited(_launchAuthUrl(newUrl));
      }
    }).catchError(
      (e) => _handleAuthFailure(
        authAttempt,
        e,
        'query account authentication',
      ),
    );
  }

  int _resetState() {
    _updateTimer?.cancel();
    setState(() {
      _invalidateAuthAttempt();
      _stateMsg = _waitingAccountAuth;
      _failedMsg = '';
    });
    return _authAttempt;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ButtonOP(
          op: widget.config.op,
          curOP: widget.curOP,
          icon: widget.config.icon,
          primaryColor: str2color(widget.config.op, 0x7f),
          height: 36,
          canStartAuth: widget.canStartAuth,
          onTap: () async {
            if (!widget.canStartAuth()) {
              return;
            }
            final authAttempt = _resetState();
            try {
              final started = await widget.startAuth(widget.config.op);
              if (!started) {
                return;
              }
            } catch (e) {
              await _handleAuthFailure(
                authAttempt,
                e,
                'start account authentication',
              );
              return;
            }
            if (!mounted ||
                authAttempt != _authAttempt ||
                widget.curOP.value != widget.config.op) {
              return;
            }
            _beginQueryState(authAttempt);
          },
        ),
        Obx(() {
          if (widget.curOP.isNotEmpty &&
              widget.curOP.value != widget.config.op) {
            _failedMsg = '';
          }
          final authAttempt = _authAttempt;
          final authUrl = _url;
          return Offstage(
            offstage:
                _failedMsg.isEmpty && widget.curOP.value != widget.config.op,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (_stateMsg.isNotEmpty && _failedMsg.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: OidcAuthStatus(
                      message: translate(_stateMsg),
                      browserFallbackPrompt: translate(
                        "Browser didn't open? Use the url below to sign in.",
                      ),
                      authUrl: authUrl,
                      copyLabel: translate('Copy to clipboard'),
                      onCopy: authUrl.isEmpty
                          ? null
                          : () => _runCurrentAuthUrlAction(
                                authAttempt,
                                authUrl,
                                _copyAuthUrl,
                              ),
                    ),
                  ),
                if (_failedMsg.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Builder(builder: (context) {
                      final errorColor = Theme.of(context).colorScheme.error;
                      final bgColor = Theme.of(context)
                          .colorScheme
                          .errorContainer
                          .withOpacity(0.3);
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8.0, vertical: 6.0),
                        decoration: BoxDecoration(
                          color: bgColor,
                          borderRadius: BorderRadius.circular(4.0),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.error_outline,
                                color: errorColor, size: 16),
                            const SizedBox(width: 6),
                            Flexible(
                              child: SelectableText(
                                translate(_failedMsg),
                                style:
                                    DefaultTextStyle.of(context).style.copyWith(
                                          fontSize: 13,
                                          color: errorColor,
                                        ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class LoginWidgetOP extends StatelessWidget {
  final List<ConfigOP> ops;
  final RxString curOP;
  final Function(Map<String, dynamic>) cbLogin;
  final Future<bool> Function(String) startAuth;
  final Future<bool> Function(String) cancelAuth;
  final bool Function() canStartAuth;

  LoginWidgetOP({
    Key? key,
    required this.ops,
    required this.curOP,
    required this.cbLogin,
    required this.startAuth,
    required this.cancelAuth,
    required this.canStartAuth,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    var children = ops
        .map((op) => [
              WidgetOP(
                config: op,
                curOP: curOP,
                cbLogin: cbLogin,
                startAuth: startAuth,
                cancelAuth: cancelAuth,
                canStartAuth: canStartAuth,
              ),
              const Divider(
                indent: 5,
                endIndent: 5,
              )
            ])
        .expand((i) => i)
        .toList();
    if (children.isNotEmpty) {
      children.removeLast();
    }
    return SingleChildScrollView(
        child: Container(
            width: 200,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: children,
            )));
  }
}

enum _AuthView { login, register, forgotPassword }

class LoginWidgetUserPass extends StatelessWidget {
  final TextEditingController username;
  final TextEditingController pass;
  final String? usernameMsg;
  final String? passMsg;
  final bool isInProgress;
  final RxString curOP;
  final Function() onLogin;
  final Function()? onGoToRegister;
  final Function()? onGoToForgotPassword;
  final FocusNode? userFocusNode;

  const LoginWidgetUserPass({
    Key? key,
    this.userFocusNode,
    required this.username,
    required this.pass,
    required this.usernameMsg,
    required this.passMsg,
    required this.isInProgress,
    required this.curOP,
    required this.onLogin,
    this.onGoToRegister,
    this.onGoToForgotPassword,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
        padding: EdgeInsets.all(0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 8.0),
            DialogTextField(
                title: translate(DialogTextField.kUsernameTitle),
                controller: username,
                focusNode: userFocusNode,
                prefixIcon: DialogTextField.kUsernameIcon,
                errorText: usernameMsg),
            PasswordWidget(
              controller: pass,
              autoFocus: false,
              reRequestFocus: true,
              errorText: passMsg,
            ),
            if (isInProgress) const LinearProgressIndicator(),
            const SizedBox(height: 12.0),
            FittedBox(
                child:
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(
                height: 38,
                width: 200,
                child: Obx(() => ElevatedButton(
                      child: Text(
                        translate('Login'),
                        style: TextStyle(fontSize: 16),
                      ),
                      onPressed: curOP.value.isEmpty && !isInProgress
                          ? () {
                              onLogin();
                            }
                          : null,
                    )),
              ),
            ])),
            const SizedBox(height: 8.0),
            TextButton(
              onPressed: onGoToRegister,
              child: const Text('Hesabınız yok mu? Kayıt Olun'),
            ),
            TextButton(
              onPressed: onGoToForgotPassword,
              child: const Text('Şifremi Unuttum', style: TextStyle(color: Colors.grey)),
            ),
          ],
        ));
  }
}

const kAuthReqTypeOidc = 'oidc/';

Future<bool?>? _activeLoginDialog;

// call this directly
Future<bool?> loginDialog() {
  final activeDialog = _activeLoginDialog;
  if (activeDialog != null) {
    return activeDialog;
  }
  final dialog = _openLoginDialogOnce();
  _activeLoginDialog = dialog;
  return dialog;
}

Future<bool?> _openLoginDialogOnce() async {
  try {
    return await _openLoginDialog();
  } finally {
    _activeLoginDialog = null;
  }
}

Future<bool?> _openLoginDialog() async {
  var currentView = _AuthView.login;

  // Login controllers
  var username =
      TextEditingController(text: UserModel.getLocalUserInfo()?['name'] ?? '');
  var password = TextEditingController();
  final userFocusNode = FocusNode()..requestFocus();
  Timer(Duration(milliseconds: 100), () => userFocusNode..requestFocus());

  String? usernameMsg;
  String? passwordMsg;
  var isInProgress = false;
  final oidcAuth = _OidcAuthController();
  final curOP = oidcAuth.curOP;
  bool isCloseHovered = false;

  // Register state
  String registerAccountType = 'individual';
  final registerFirstName = TextEditingController();
  final registerLastName = TextEditingController();
  final registerOrgName = TextEditingController();
  final registerTaxId = TextEditingController();
  final registerEmail = TextEditingController();
  final registerPassword = TextEditingController();
  final registerConfirmPassword = TextEditingController();
  String? registerError;

  // Forgot password state
  final forgotEmail = TextEditingController();
  String? forgotError;

  final loginOptions = [].obs;
  final loginOptionsError = Rxn<Object>();
  final loginOptionsInProgress = false.obs;
  fetchLoginOptions() async {
    loginOptionsInProgress.value = true;
    try {
      loginOptions.value = await UserModel.queryOidcLoginOptions();
      loginOptionsError.value = null;
    } catch (e) {
      debugPrint("queryOidcLoginOptions failed: $e");
      loginOptionsError.value = e;
    } finally {
      loginOptionsInProgress.value = false;
    }
  }

  Future.delayed(Duration.zero, fetchLoginOptions);

  final res = await gFFI.dialogManager.show<bool>((setState, close, context) {
    username.addListener(() {
      if (usernameMsg != null) {
        setState(() => usernameMsg = null);
      }
    });

    password.addListener(() {
      if (passwordMsg != null) {
        setState(() => passwordMsg = null);
      }
    });

    onDialogCancel() {
      isInProgress = false;
      close(false);
    }

    handleLoginResponse(LoginResponse resp, bool storeIfAccessToken,
        void Function([dynamic])? close) async {
      switch (resp.type) {
        case HttpType.kAuthResTypeToken:
          if (resp.access_token != null) {
            if (storeIfAccessToken) {
              await bind.mainSetLocalOption(
                  key: 'access_token', value: resp.access_token!);
              await bind.mainSetLocalOption(
                  key: 'user_info', value: jsonEncode(resp.user ?? {}));
            }
            if (close != null) {
              close(true);
            }
            return;
          }
          break;
        case HttpType.kAuthResTypeEmailCheck:
          bool? isEmailVerification;
          if (resp.tfa_type == null ||
              resp.tfa_type == HttpType.kAuthResTypeEmailCheck) {
            isEmailVerification = true;
          } else if (resp.tfa_type == HttpType.kAuthResTypeTfaCheck) {
            isEmailVerification = false;
          } else {
            passwordMsg = "Failed, bad tfa type from server";
          }
          if (isEmailVerification != null) {
            if (isMobile) {
              if (close != null) close(null);
              verificationCodeDialog(
                  resp.user, resp.secret, isEmailVerification);
            } else {
              setState(() => isInProgress = false);
              if (isWeb && close != null) close(null);
              final res = await verificationCodeDialog(
                  resp.user, resp.secret, isEmailVerification);
              if (res == true) {
                if (!isWeb && close != null) close(false);
                return;
              }
            }
          }
          break;
        default:
          passwordMsg = "Failed, bad response from server";
          break;
      }
    }

    onLogin() async {
      if (curOP.value.isNotEmpty || isInProgress) {
        return;
      }
      if (username.text.isEmpty) {
        setState(() => usernameMsg = translate('Username missed'));
        return;
      }
      if (password.text.isEmpty) {
        setState(() => passwordMsg = translate('Password missed'));
        return;
      }
      curOP.value = 'rustdesk';
      setState(() => isInProgress = true);
      try {
        final resp = await gFFI.userModel.login(LoginRequest(
            username: username.text,
            password: password.text,
            id: await bind.mainGetMyId(),
            uuid: await bind.mainGetUuid(),
            autoLogin: true,
            type: HttpType.kAuthReqTypeAccount));
        await handleLoginResponse(resp, true, close);
      } on RequestException catch (err) {
        passwordMsg = translate(err.cause);
      } catch (err) {
        passwordMsg = "Unknown Error: $err";
      }
      curOP.value = '';
      setState(() => isInProgress = false);
    }

    onRegisterSubmit() async {
      if (registerFirstName.text.trim().length < 2) {
        setState(() => registerError = 'Ad en az 2 karakter olmalıdır.');
        return;
      }
      if (registerLastName.text.trim().length < 2) {
        setState(() => registerError = 'Soyad en az 2 karakter olmalıdır.');
        return;
      }
      if (registerEmail.text.trim().isEmpty || !registerEmail.text.contains('@')) {
        setState(() => registerError = 'Geçerli bir e-posta adresi giriniz.');
        return;
      }
      if (registerPassword.text.length < 4) {
        setState(() => registerError = 'Şifre en az 4 karakter olmalıdır.');
        return;
      }
      if (registerPassword.text != registerConfirmPassword.text) {
        setState(() => registerError = 'Şifreler eşleşmiyor.');
        return;
      }
      if (registerAccountType == 'company') {
        if (registerOrgName.text.trim().isEmpty) {
          setState(() => registerError = 'Firma adı gereklidir.');
          return;
        }
        if (registerTaxId.text.trim().isEmpty) {
          setState(() => registerError = 'Vergi numarası gereklidir.');
          return;
        }
      }

      setState(() {
        isInProgress = true;
        registerError = null;
      });

      try {
        final url = await bind.mainGetApiServer();
        final body = {
          'account_type': registerAccountType,
          'first_name': registerFirstName.text.trim(),
          'last_name': registerLastName.text.trim(),
          'org_name': registerAccountType == 'company' ? registerOrgName.text.trim() : '',
          'tax_id': registerAccountType == 'company' ? registerTaxId.text.trim() : '',
          'email': registerEmail.text.trim(),
          'password': registerPassword.text,
          'confirm_password': registerConfirmPassword.text,
          'locale': 'tr',
        };

        final response = await http.post(
          Uri.parse('$url/api/register'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(body),
        );

        final data = json.decode(response.body);
        if (response.statusCode != 200) {
          throw data['error'] ?? data['msg'] ?? 'Kayıt başarısız oldu.';
        }

        if (data['type'] == 'access_token') {
          await bind.mainSetLocalOption(key: 'access_token', value: data['access_token']);
          await bind.mainSetLocalOption(key: 'user_info', value: json.encode(data['user']));
          gFFI.userModel.refreshCurrentUser();
          close(true);
        } else if (data['type'] == 'email_check') {
          showToast('Kayıt başarılı! Lütfen e-posta adresinizi doğrulayın.');
          setState(() => currentView = _AuthView.login);
        } else {
          showToast('Kayıt başarılı! Yönetici onayından sonra giriş yapabilirsiniz.');
          setState(() => currentView = _AuthView.login);
        }
      } catch (e) {
        setState(() => registerError = e.toString().replaceAll('Exception: ', ''));
      } finally {
        setState(() => isInProgress = false);
      }
    }

    onForgotPasswordSubmit() async {
      if (forgotEmail.text.trim().isEmpty || !forgotEmail.text.contains('@')) {
        setState(() => forgotError = 'Lütfen geçerli bir e-posta adresi giriniz.');
        return;
      }
      setState(() {
        isInProgress = true;
        forgotError = null;
      });

      try {
        final url = await bind.mainGetApiServer();
        final response = await http.post(
          Uri.parse('$url/api/forgot-password'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'email': forgotEmail.text.trim()}),
        );
        if (response.statusCode == 200) {
          showToast('Şifre sıfırlama bağlantısı e-posta adresinize gönderildi.');
          setState(() => currentView = _AuthView.login);
        } else {
          final data = json.decode(response.body);
          throw data['error'] ?? data['msg'] ?? 'Şifre sıfırlama talebi başarısız oldu.';
        }
      } catch (e) {
        setState(() => forgotError = e.toString().replaceAll('Exception: ', ''));
      } finally {
        setState(() => isInProgress = false);
      }
    }

    thirdAuthWidget() => Obx(() {
          final error = loginOptionsError.value;
          final inProgress = loginOptionsInProgress.value;
          if (error != null) {
            return Column(
              children: [
                const SizedBox(height: 8.0),
                if (inProgress) const LinearProgressIndicator(),
                if (!inProgress && error is! RequestException)
                  Text(
                    translate('network_error_tip'),
                    style: const TextStyle(fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.primary,
                  ),
                  onPressed: inProgress ? null : fetchLoginOptions,
                  child: Text(translate('Retry')),
                ),
                if (!inProgress)
                  SelectableText(
                    error.toString(),
                    style: const TextStyle(fontSize: 11, color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
              ],
            );
          }
          return Offstage(
            offstage: loginOptions.isEmpty,
            child: Column(
              children: [
                const SizedBox(height: 8.0),
                Center(
                    child: Text(
                  translate('or'),
                  style: const TextStyle(fontSize: 16),
                )),
                const SizedBox(height: 8.0),
                LoginWidgetOP(
                  ops: loginOptions
                      .map((e) => ConfigOP(op: e['name'], icon: e['icon']))
                      .toList(),
                  curOP: curOP,
                  startAuth: oidcAuth.start,
                  cancelAuth: oidcAuth.cancelCurrent,
                  canStartAuth: oidcAuth.canStart,
                  cbLogin: (Map<String, dynamic> authBody) async {
                    LoginResponse? resp;
                    try {
                      resp =
                          gFFI.userModel.getLoginResponseFromAuthBody(authBody);
                    } catch (e) {
                      debugPrint(
                          'Failed to parse oidc login body: "$authBody"');
                    }
                    close(true);

                    if (resp != null) {
                      handleLoginResponse(resp, false, null);
                    }
                  },
                ),
              ],
            ),
          );
        });

    String titleText = translate('Login');
    if (currentView == _AuthView.register) {
      titleText = 'Kayıt Ol - AcilBir';
    } else if (currentView == _AuthView.forgotPassword) {
      titleText = 'Şifre Sıfırlama';
    }

    final title = Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titleText,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ).marginOnly(top: MyTheme.dialogPadding),
        MouseRegion(
          onEnter: (_) => setState(() => isCloseHovered = true),
          onExit: (_) => setState(() => isCloseHovered = false),
          child: InkWell(
            child: Icon(
              Icons.close,
              size: 25,
              color: isCloseHovered
                  ? Colors.white
                  : Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.color
                      ?.withOpacity(0.55),
            ),
            onTap: onDialogCancel,
            hoverColor: Colors.red,
            borderRadius: BorderRadius.circular(5),
          ),
        ).marginOnly(top: 10, right: 15),
      ],
    );
    final titlePadding = EdgeInsets.fromLTRB(MyTheme.dialogPadding, 0, 0, 0);

    Widget buildCurrentBody() {
      if (currentView == _AuthView.register) {
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (registerError != null)
                Container(
                  padding: const EdgeInsets.all(8),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Text(
                    registerError!,
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ),
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<String>(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Bireysel', style: TextStyle(fontSize: 13)),
                      value: 'individual',
                      groupValue: registerAccountType,
                      onChanged: (v) => setState(() => registerAccountType = v ?? 'individual'),
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<String>(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Kurumsal', style: TextStyle(fontSize: 13)),
                      value: 'company',
                      groupValue: registerAccountType,
                      onChanged: (v) => setState(() => registerAccountType = v ?? 'company'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: DialogTextField(
                      title: 'Ad *',
                      controller: registerFirstName,
                      prefixIcon: const Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DialogTextField(
                      title: 'Soyad *',
                      controller: registerLastName,
                      prefixIcon: const Icon(Icons.person_outline),
                    ),
                  ),
                ],
              ),
              if (registerAccountType == 'company') ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: DialogTextField(
                        title: 'Firma Adı *',
                        controller: registerOrgName,
                        prefixIcon: const Icon(Icons.business_outlined),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DialogTextField(
                        title: 'Vergi No (VKN) *',
                        controller: registerTaxId,
                        prefixIcon: const Icon(Icons.numbers_outlined),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 4),
              DialogTextField(
                title: 'E-posta Adresi *',
                controller: registerEmail,
                prefixIcon: const Icon(Icons.email_outlined),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: PasswordWidget(
                      controller: registerPassword,
                      autoFocus: false,
                      reRequestFocus: false,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: PasswordWidget(
                      controller: registerConfirmPassword,
                      autoFocus: false,
                      reRequestFocus: false,
                    ),
                  ),
                ],
              ),
              if (isInProgress) const LinearProgressIndicator(),
              const SizedBox(height: 12),
              Center(
                child: SizedBox(
                  height: 38,
                  width: 220,
                  child: ElevatedButton(
                    onPressed: isInProgress ? null : onRegisterSubmit,
                    child: const Text('Kayıt Ol', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              TextButton(
                onPressed: () => setState(() {
                  registerError = null;
                  currentView = _AuthView.login;
                }),
                child: const Text('Zaten bir hesabınız var mı? Giriş Yapın'),
              ),
            ],
          ),
        );
      } else if (currentView == _AuthView.forgotPassword) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Kayıtlı e-posta adresinizi girin. Size bir şifre sıfırlama bağlantısı göndereceğiz.',
              style: TextStyle(fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            if (forgotError != null)
              Container(
                padding: const EdgeInsets.all(8),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Text(
                  forgotError!,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
            DialogTextField(
              title: 'E-posta Adresi',
              controller: forgotEmail,
              prefixIcon: const Icon(Icons.email_outlined),
            ),
            if (isInProgress) const LinearProgressIndicator(),
            const SizedBox(height: 16),
            Center(
              child: SizedBox(
                height: 38,
                width: 220,
                child: ElevatedButton(
                  onPressed: isInProgress ? null : onForgotPasswordSubmit,
                  child: const Text('Sıfırlama Bağlantısı Gönder', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
            const SizedBox(height: 6),
            TextButton(
              onPressed: () => setState(() {
                forgotError = null;
                currentView = _AuthView.login;
              }),
              child: const Text('Giriş Ekranına Dön'),
            ),
          ],
        );
      } else {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 8.0),
            LoginWidgetUserPass(
              username: username,
              pass: password,
              usernameMsg: usernameMsg,
              passMsg: passwordMsg,
              isInProgress: isInProgress,
              curOP: curOP,
              onLogin: onLogin,
              onGoToRegister: () => setState(() {
                registerError = null;
                currentView = _AuthView.register;
              }),
              onGoToForgotPassword: () => setState(() {
                forgotError = null;
                currentView = _AuthView.forgotPassword;
              }),
              userFocusNode: userFocusNode,
            ),
            thirdAuthWidget(),
          ],
        );
      }
    }

    return CustomAlertDialog(
      title: title,
      titlePadding: titlePadding,
      contentBoxConstraints: const BoxConstraints(minWidth: 420, maxWidth: 460),
      content: buildCurrentBody(),
      onCancel: onDialogCancel,
      onSubmit: () {
        if (currentView == _AuthView.login) {
          onLogin();
        } else if (currentView == _AuthView.register) {
          onRegisterSubmit();
        } else if (currentView == _AuthView.forgotPassword) {
          onForgotPasswordSubmit();
        }
      },
    );
  }).whenComplete(oidcAuth.close);

  if (res != null) {
    await UserModel.updateOtherModels();
  }

  return res;
}

Future<bool?> verificationCodeDialog(
    UserPayload? user, String? secret, bool isEmailVerification) async {
  var autoLogin = true;
  var isInProgress = false;
  String? errorText;

  final code = TextEditingController();

  final res = await gFFI.dialogManager.show<bool>((setState, close, context) {
    void onVerify() async {
      setState(() => isInProgress = true);

      try {
        final resp = await gFFI.userModel.login(LoginRequest(
            verificationCode: code.text,
            tfaCode: isEmailVerification ? null : code.text,
            secret: secret,
            username: user?.name,
            id: await bind.mainGetMyId(),
            uuid: await bind.mainGetUuid(),
            autoLogin: autoLogin,
            type: HttpType.kAuthReqTypeEmailCode));

        switch (resp.type) {
          case HttpType.kAuthResTypeToken:
            if (resp.access_token != null) {
              await bind.mainSetLocalOption(
                  key: 'access_token', value: resp.access_token!);
              close(true);
              return;
            }
            break;
          default:
            errorText = "Failed, bad response from server";
            break;
        }
      } on RequestException catch (err) {
        errorText = translate(err.cause);
      } catch (err) {
        errorText = "Unknown Error: $err";
      }

      setState(() => isInProgress = false);
    }

    final codeField = isEmailVerification
        ? DialogEmailCodeField(
            controller: code,
            errorText: errorText,
            readyCallback: onVerify,
            onChanged: () => errorText = null,
          )
        : Dialog2FaField(
            controller: code,
            errorText: errorText,
            readyCallback: onVerify,
            onChanged: () => errorText = null,
          );

    getOnSubmit() => codeField.isReady ? onVerify : null;

    return CustomAlertDialog(
        title: Text(translate("Verification code")),
        contentBoxConstraints: BoxConstraints(maxWidth: 300),
        content: Column(
          children: [
            Offstage(
                offstage: !isEmailVerification || user?.email == null,
                child: TextField(
                  decoration: InputDecoration(
                      labelText: "Email", prefixIcon: Icon(Icons.email)),
                  readOnly: true,
                  controller: TextEditingController(text: user?.email),
                ).workaroundFreezeLinuxMint()),
            isEmailVerification ? const SizedBox(height: 8) : const Offstage(),
            codeField,
            /*
            CheckboxListTile(
              contentPadding: const EdgeInsets.all(0),
              dense: true,
              controlAffinity: ListTileControlAffinity.leading,
              title: Row(children: [
                Expanded(child: Text(translate("Trust this device")))
              ]),
              value: trustThisDevice,
              onChanged: (v) {
                if (v == null) return;
                setState(() => trustThisDevice = !trustThisDevice);
              },
            ),
            */
            // NOT use Offstage to wrap LinearProgressIndicator
            if (isInProgress) const LinearProgressIndicator(),
          ],
        ),
        onCancel: close,
        onSubmit: getOnSubmit(),
        actions: [
          dialogButton("Cancel", onPressed: close, isOutline: true),
          dialogButton("Verify", onPressed: getOnSubmit()),
        ]);
  });
  // For verification code, desktop update other models in login dialog, mobile need to close login dialog first,
  // otherwise the soft keyboard will jump out on each key press, so mobile update in verification code dialog.
  if (isMobile && res == true) {
    await UserModel.updateOtherModels();
  }

  return res;
}

void logOutConfirmDialog() {
  gFFI.dialogManager.show((setState, close, context) {
    submit() {
      close();
      gFFI.userModel.logOut();
    }

    return CustomAlertDialog(
      content: Text(translate("logout_tip")),
      actions: [
        dialogButton(translate("Cancel"), onPressed: close, isOutline: true),
        dialogButton(translate("OK"), onPressed: submit),
      ],
      onSubmit: submit,
      onCancel: close,
    );
  });
}

Future<void> forgotPasswordDialog() async {
  final emailController = TextEditingController();
  bool isLoading = false;

  await Get.dialog(
    StatefulBuilder(builder: (context, setState) {
      return AlertDialog(
        title: const Text('Şifre Sıfırlama'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Kayıtlı e-posta adresinizi girin. Size bir sıfırlama bağlantısı göndereceğiz.'),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: 'E-posta adresi'),
            ),
            if (isLoading)
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: CircularProgressIndicator(),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: isLoading
                ? null
                : () async {
                    if (emailController.text.trim().isEmpty) return;
                    setState(() => isLoading = true);
                    try {
                      final url = await bind.mainGetApiServer();
                      final response = await http.post(
                        Uri.parse('$url/api/forgot-password'),
                        headers: {'Content-Type': 'application/json'},
                        body: json.encode({'email': emailController.text.trim()}),
                      );
                      if (response.statusCode == 200) {
                        Get.back();
                        showToast('Şifre sıfırlama bağlantısı gönderildi.');
                      } else {
                        final data = json.decode(response.body);
                        throw data['error'] ?? 'Bilinmeyen bir hata oluştu.';
                      }
                    } catch (e) {
                      Get.snackbar('Hata', e.toString());
                    } finally {
                      if (context.mounted) {
                        setState(() => isLoading = false);
                      }
                    }
                  },
            child: const Text('Gönder'),
          ),
        ],
      );
    }),
  );
}

