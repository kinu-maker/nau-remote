import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/common/hbbs/hbbs.dart';
import 'package:flutter_hbb/common/widgets/login.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:flutter_hbb/models/user_model.dart';
import 'package:get/get.dart';

import 'nau_theme.dart';

class _NauOidcAuth {
  final RxString curOP = ''.obs;
  bool _busy = false;
  bool _closed = false;

  bool canStart() => !_closed && !_busy;

  Future<bool> start(String op) async {
    if (!canStart()) return false;
    _busy = true;
    curOP.value = op;
    try {
      await bind.mainAccountAuthCancel();
      await bind.mainAccountAuth(op: op, rememberMe: true);
      return !_closed && curOP.value == op;
    } finally {
      _busy = false;
    }
  }

  Future<bool> cancel(String op) async {
    if (!canStart() || curOP.value != op) return false;
    _busy = true;
    try {
      await bind.mainAccountAuthCancel();
      return !_closed && curOP.value == op;
    } finally {
      _busy = false;
    }
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    final active = curOP.value.isNotEmpty && curOP.value != 'rustdesk';
    curOP.value = '';
    if (active) {
      try {
        await bind.mainAccountAuthCancel();
      } catch (e) {
        debugPrint('Failed to cancel account authentication $e');
      }
    }
  }
}

class NauLoginPage extends StatefulWidget {
  const NauLoginPage({Key? key}) : super(key: key);

  @override
  State<NauLoginPage> createState() => _NauLoginPageState();
}

class _NauLoginPageState extends State<NauLoginPage> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _oidc = _NauOidcAuth();
  final _options = <dynamic>[].obs;
  final _optionsLoading = true.obs;
  final _optionsError = ''.obs;
  bool _showAccountForm = false;
  bool _inProgress = false;
  String? _usernameError;
  String? _passwordError;

  @override
  void initState() {
    super.initState();
    _username.text = (UserModel.getLocalUserInfo()?['name'] ?? '').toString();
    _fetchOptions();
  }

  @override
  void dispose() {
    _oidc.close();
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _fetchOptions() async {
    _optionsLoading.value = true;
    _optionsError.value = '';
    try {
      // "webauth" is the server's own web login page, not a company sign-in.
      _options.value = (await UserModel.queryOidcLoginOptions())
          .where((e) => e['name'] != 'webauth')
          .toList();
    } catch (e) {
      debugPrint('queryOidcLoginOptions failed: $e');
      _optionsError.value = '서버에 연결하지 못했습니다. 인터넷 연결을 확인한 뒤 다시 시도하세요.';
    } finally {
      _optionsLoading.value = false;
    }
  }

  Future<void> _handleResponse(LoginResponse resp, bool storeToken) async {
    switch (resp.type) {
      case HttpType.kAuthResTypeToken:
        if (resp.access_token == null) {
          _passwordError = '로그인에 실패했습니다. 다시 시도하세요.';
          return;
        }
        if (storeToken) {
          await bind.mainSetLocalOption(
              key: 'access_token', value: resp.access_token!);
          await bind.mainSetLocalOption(
              key: 'user_info', value: jsonEncode(resp.user ?? {}));
        }
        await UserModel.updateOtherModels();
        return;
      case HttpType.kAuthResTypeEmailCheck:
        final isEmail = resp.tfa_type == null ||
            resp.tfa_type == HttpType.kAuthResTypeEmailCheck;
        if (!isEmail && resp.tfa_type != HttpType.kAuthResTypeTfaCheck) {
          _passwordError = '서버가 알 수 없는 인증 방식을 요구했습니다.';
          return;
        }
        final ok =
            await verificationCodeDialog(resp.user, resp.secret, isEmail);
        if (ok == true) {
          await UserModel.updateOtherModels();
        }
        return;
      default:
        _passwordError = '서버 응답을 이해하지 못했습니다. 다시 시도하세요.';
    }
  }

  Future<void> _loginWithAccount() async {
    if (_inProgress || _oidc.curOP.value.isNotEmpty) return;
    setState(() {
      _usernameError = _username.text.trim().isEmpty ? '아이디를 입력하세요.' : null;
      _passwordError = _password.text.isEmpty ? '비밀번호를 입력하세요.' : null;
    });
    if (_usernameError != null || _passwordError != null) return;
    _oidc.curOP.value = 'rustdesk';
    setState(() => _inProgress = true);
    try {
      final resp = await gFFI.userModel.login(LoginRequest(
          username: _username.text.trim(),
          password: _password.text,
          id: await bind.mainGetMyId(),
          uuid: await bind.mainGetUuid(),
          autoLogin: true,
          type: HttpType.kAuthReqTypeAccount));
      await _handleResponse(resp, true);
    } on RequestException catch (err) {
      _passwordError = translate(err.cause);
    } catch (err) {
      debugPrint('login failed: $err');
      _passwordError = '서버에 연결하지 못했습니다. 인터넷 연결을 확인한 뒤 다시 시도하세요.';
    }
    _oidc.curOP.value = '';
    if (mounted) setState(() => _inProgress = false);
  }

  Future<void> _onOidcLogin(Map<String, dynamic> authBody) async {
    try {
      // The access token is already stored on the Rust side.
      final resp = gFFI.userModel.getLoginResponseFromAuthBody(authBody);
      await _handleResponse(resp, false);
    } catch (e) {
      debugPrint('Failed to parse oidc login body: $e');
    }
    if (mounted) setState(() {});
  }

  Widget _buildOidc() {
    return Obx(() {
      if (_optionsLoading.value) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 14),
          child: Center(
              child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2))),
        );
      }
      if (_optionsError.value.isNotEmpty) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(_optionsError.value,
                textAlign: TextAlign.center,
                style: nauText(size: 13, color: NauColors.danger, height: 1.5)),
            const SizedBox(height: 12),
            NauButton(label: '다시 시도', onPressed: _fetchOptions),
          ],
        );
      }
      if (_options.isEmpty) {
        return const SizedBox.shrink();
      }
      return Center(
        child: LoginWidgetOP(
          ops: _options
              .map((e) => ConfigOP(op: e['name'], icon: e['icon']))
              .toList(),
          curOP: _oidc.curOP,
          startAuth: _oidc.start,
          cancelAuth: _oidc.cancel,
          canStartAuth: _oidc.canStart,
          cbLogin: _onOidcLogin,
        ),
      );
    });
  }

  Widget _buildAccountForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _username,
          enabled: !_inProgress,
          style: nauText(),
          autofillHints: const [AutofillHints.username],
          decoration:
              nauInputDecoration(hint: '아이디', errorText: _usernameError),
          onChanged: (_) {
            if (_usernameError != null) setState(() => _usernameError = null);
          },
          onSubmitted: (_) => _loginWithAccount(),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _password,
          enabled: !_inProgress,
          obscureText: true,
          style: nauText(),
          autofillHints: const [AutofillHints.password],
          decoration:
              nauInputDecoration(hint: '비밀번호', errorText: _passwordError),
          onChanged: (_) {
            if (_passwordError != null) setState(() => _passwordError = null);
          },
          onSubmitted: (_) => _loginWithAccount(),
        ),
        const SizedBox(height: 14),
        NauButton(
          label: _inProgress ? '로그인 중…' : '로그인',
          primary: true,
          height: 48,
          onPressed: _inProgress ? null : _loginWithAccount,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: NauColors.background,
      child: Stack(
        children: [
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const NauLogo(size: 64),
                    const SizedBox(height: 16),
                    Text(kNauAppTitle,
                        style: nauText(size: 30, weight: FontWeight.w700)),
                    const SizedBox(height: 16),
                    Text('회사 계정으로 로그인하면\n내 컴퓨터가 바로 보입니다.',
                        textAlign: TextAlign.center,
                        style: nauText(
                            size: 15,
                            color: NauColors.textSecondary,
                            height: 1.6)),
                    const SizedBox(height: 28),
                    NauPanel(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildOidc(),
                          Obx(() {
                            final hasOidc = _options.isNotEmpty;
                            if (!hasOidc && !_optionsLoading.value) {
                              return _buildAccountForm();
                            }
                            if (!hasOidc) return const SizedBox.shrink();
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const SizedBox(height: 14),
                                Text(
                                    '브라우저가 열리면 회사 이메일을 선택하세요.\n로그인하면 이 컴퓨터가 내 목록에 자동으로 등록됩니다.',
                                    textAlign: TextAlign.center,
                                    style: nauText(
                                        size: 13,
                                        color: NauColors.textSecondary,
                                        height: 1.5)),
                                const SizedBox(height: 10),
                                if (_showAccountForm) _buildAccountForm(),
                                if (!_showAccountForm)
                                  TextButton(
                                    onPressed: () =>
                                        setState(() => _showAccountForm = true),
                                    child: Text('아이디와 비밀번호로 로그인',
                                        style: nauText(
                                            size: 13,
                                            color: NauColors.textMuted)),
                                  ),
                              ],
                            );
                          }),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    Obx(() => Offstage(
                          offstage: _options.isEmpty,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.lock_outline,
                                  size: 16, color: NauColors.textSecondary),
                              const SizedBox(width: 8),
                              Text('@$kNauLoginDomain 계정만 로그인할 수 있습니다',
                                  style: nauText(
                                      size: 13,
                                      color: NauColors.textSecondary)),
                            ],
                          ),
                        )),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 20,
            child: Text('버전 $version',
                textAlign: TextAlign.center,
                style: nauText(size: 12, color: NauColors.textSecondary)),
          ),
        ],
      ),
    );
  }
}
