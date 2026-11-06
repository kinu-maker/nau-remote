import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/common/formatter/id_formatter.dart';
import 'package:flutter_hbb/common/widgets/login.dart';
import 'package:flutter_hbb/consts.dart';
import 'package:flutter_hbb/desktop/pages/desktop_keyboard_shortcuts_page.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:get/get.dart';

import 'nau_theme.dart';

class NauSettingsPage extends StatefulWidget {
  final VoidCallback onOpenAdvanced;
  const NauSettingsPage({Key? key, required this.onOpenAdvanced})
      : super(key: key);

  @override
  State<NauSettingsPage> createState() => _NauSettingsPageState();
}

class _NauSettingsPageState extends State<NauSettingsPage> {
  bool _allowRemote = true;
  String _quality = kRemoteImageQualityBalanced;
  String _myId = '';

  static const _qualityLabels = {
    kRemoteImageQualityBalanced: '자동',
    kRemoteImageQualityBest: '선명하게',
    kRemoteImageQualityLow: '부드럽게',
  };

  @override
  void initState() {
    super.initState();
    _allowRemote = !mainGetBoolOptionSync(kOptionStopService);
    final quality = bind.mainGetUserDefaultOption(key: kOptionImageQuality);
    if (_qualityLabels.containsKey(quality)) _quality = quality;
    bind.mainGetMyId().then((id) {
      if (mounted) setState(() => _myId = id);
    });
  }

  Future<void> _setAllowRemote(bool allow) async {
    setState(() => _allowRemote = allow);
    await mainSetBoolOption(kOptionStopService, !allow);
  }

  Future<void> _setQuality(String? value) async {
    if (value == null) return;
    setState(() => _quality = value);
    await bind.mainSetUserDefaultOption(key: kOptionImageQuality, value: value);
  }

  String _hostname() {
    try {
      return Platform.localHostname;
    } catch (_) {
      return '';
    }
  }

  Widget _row({required Widget label, required Widget trailing}) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 44),
      child: Row(
        children: [
          Expanded(child: label),
          const SizedBox(width: 16),
          trailing,
        ],
      ),
    );
  }

  Widget _label(String title, [String? description]) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: nauText()),
        if (description != null)
          Text(description,
              style: nauText(
                  size: 12, color: NauColors.textSecondary, height: 1.5)),
      ],
    );
  }

  Widget _group(String title, List<Widget> rows) {
    return NauPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: nauText(size: 15, weight: FontWeight.w700)),
          const SizedBox(height: 10),
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const SizedBox(height: 6),
            rows[i],
          ],
        ],
      ),
    );
  }

  Widget _thisComputer() {
    final hostname = _hostname();
    return _group('이 컴퓨터', [
      _row(
        label: _label('원격 접속 허용', '내 계정으로 로그인한 기기에서 이 컴퓨터에 들어올 수 있습니다'),
        trailing: Switch(
          value: _allowRemote,
          activeColor: NauColors.accent,
          onChanged: _setAllowRemote,
        ),
      ),
      _row(
        label: _label('컴퓨터 이름'),
        trailing: Text(hostname.isEmpty ? '알 수 없음' : hostname,
            style: nauText(color: NauColors.textMuted)),
      ),
      _row(
        label: _label('컴퓨터 번호'),
        trailing: SelectableText(_myId.isEmpty ? '확인 중…' : formatID(_myId),
            style: nauText(color: NauColors.textMuted)),
      ),
    ]);
  }

  Widget _display() {
    return _group('화면', [
      _row(
        label: _label('화질', '새로 연결할 때부터 적용됩니다'),
        trailing: Container(
          width: 200,
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: NauColors.field,
            border: Border.all(color: NauColors.fieldBorder),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _quality,
              isExpanded: true,
              dropdownColor: NauColors.panel,
              style: nauText(),
              items: _qualityLabels.entries
                  .map((e) =>
                      DropdownMenuItem(value: e.key, child: Text(e.value)))
                  .toList(),
              onChanged: _setQuality,
            ),
          ),
        ),
      ),
    ]);
  }

  Widget _shortcuts() {
    return _group('단축키', [
      _row(
        label: _label('키보드 단축키', '전체 화면, 연결 끊기 같은 동작에 쓸 키를 정합니다'),
        trailing: NauButton(
          label: '단축키 설정',
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => const DesktopKeyboardShortcutsPage(),
          )),
        ),
      ),
    ]);
  }

  Widget _account() {
    return _group('계정', [
      Obx(() => _row(
            label: _label(gFFI.userModel.accountLabelWithHandle, '로그인됨'),
            trailing: NauButton(label: '로그아웃', onPressed: logOutConfirmDialog),
          )),
      _row(
        label: _label('버전 $version'),
        trailing: NauButton(label: '고급 설정', onPressed: widget.onOpenAdvanced),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(32, 28, 32, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 44,
            child: Align(
              alignment: Alignment.centerLeft,
              child:
                  Text('설정', style: nauText(size: 26, weight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 22),
          LayoutBuilder(builder: (context, constraints) {
            final twoColumns = constraints.maxWidth >= 760;
            final width = twoColumns
                ? (constraints.maxWidth - 20) / 2
                : constraints.maxWidth;
            return Wrap(
              spacing: 20,
              runSpacing: 20,
              children: [
                SizedBox(width: width, child: _thisComputer()),
                SizedBox(width: width, child: _display()),
                SizedBox(width: width, child: _shortcuts()),
                SizedBox(width: width, child: _account()),
              ],
            );
          }),
        ],
      ),
    );
  }
}
