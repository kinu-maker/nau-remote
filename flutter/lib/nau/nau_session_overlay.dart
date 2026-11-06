import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/common/shared_state.dart';
import 'package:flutter_hbb/common/widgets/dialog.dart';
import 'package:flutter_hbb/consts.dart';
import 'package:flutter_hbb/desktop/widgets/tabbar_widget.dart';
import 'package:flutter_hbb/models/model.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:flutter_hbb/models/state_model.dart';
import 'package:get/get.dart';

import 'nau_theme.dart';

/// The stock toolbar stays built (it owns the keyboard shortcuts) but is only
/// shown on request.
final nauShowLegacyToolbar = false.obs;

const _kQualityOrder = [
  kRemoteImageQualityBalanced,
  kRemoteImageQualityBest,
  kRemoteImageQualityLow,
];
const _kQualityLabels = {
  kRemoteImageQualityBalanced: '자동',
  kRemoteImageQualityBest: '선명하게',
  kRemoteImageQualityLow: '부드럽게',
};

class NauSessionOverlay extends StatefulWidget {
  final String id;
  final FFI ffi;
  const NauSessionOverlay({Key? key, required this.id, required this.ffi})
      : super(key: key);

  @override
  State<NauSessionOverlay> createState() => _NauSessionOverlayState();
}

class _NauSessionOverlayState extends State<NauSessionOverlay> {
  bool _open = false;
  bool _hover = false;
  bool _statusVisible = true;
  String _quality = '';
  Timer? _statusTimer;
  Rx<String>? _direct;

  FFI get _ffi => widget.ffi;

  @override
  void initState() {
    super.initState();
    try {
      _direct = ConnectionTypeState.find(widget.id).direct;
    } catch (e) {
      debugPrint('connection type state is missing for ${widget.id}: $e');
    }
    _statusTimer = Timer(const Duration(seconds: 6), () {
      if (mounted) setState(() => _statusVisible = false);
    });
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    super.dispose();
  }

  Future<void> _toggleMenu() async {
    setState(() => _open = !_open);
    if (_open) {
      final quality =
          await bind.sessionGetImageQuality(sessionId: _ffi.sessionId) ?? '';
      if (mounted) setState(() => _quality = quality);
    }
  }

  void _close() => setState(() => _open = false);

  int _currentDisplay() {
    try {
      return CurrentDisplayState.find(widget.id).value;
    } catch (_) {
      return _ffi.ffiModel.pi.currentDisplay;
    }
  }

  void _nextDisplay() {
    final pi = _ffi.ffiModel.pi;
    final count = pi.displays.length;
    if (count < 2) return;
    final current = _currentDisplay();
    final next = current < 0 || current >= count - 1 ? 0 : current + 1;
    openMonitorInTheSameTab(next, _ffi, pi);
    setState(() {});
  }

  Future<void> _nextQuality() async {
    final index = _kQualityOrder.indexOf(_quality);
    final next = _kQualityOrder[(index + 1) % _kQualityOrder.length];
    setState(() => _quality = next);
    await bind.sessionSetImageQuality(sessionId: _ffi.sessionId, value: next);
  }

  String _peerName() {
    final label = DesktopTab.tablabelGetter(widget.id).value;
    if (label.isNotEmpty) return label;
    return _ffi.ffiModel.pi.hostname;
  }

  String _connectionLabel(String direct) {
    if (direct == ConnectionType.strDirect) return '직접 연결';
    if (direct == ConnectionType.strIndirect) return '릴레이 연결';
    return '연결됨';
  }

  Widget _buildConnectionLabel() {
    final style = nauText(size: 13, color: NauColors.textMuted);
    final direct = _direct;
    if (direct == null) return Text('연결됨', style: style);
    return Obx(() => Text(_connectionLabel(direct.value), style: style));
  }

  Widget _menuItem(
      {required IconData icon,
      required String label,
      String? trailing,
      Color color = NauColors.text,
      FontWeight weight = FontWeight.w400,
      required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Text(label,
                    overflow: TextOverflow.ellipsis,
                    style: nauText(color: color, weight: weight)),
              ),
              if (trailing != null)
                Text(trailing,
                    style: nauText(size: 12, color: NauColors.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenu() {
    final pi = _ffi.ffiModel.pi;
    final displayCount = pi.displays.length;
    final isWindowsPeer = pi.platform == kPeerPlatformWindows;
    return Container(
      width: 280,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: NauColors.panel,
        border: Border.all(color: NauColors.panelBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Obx(() => _menuItem(
                icon: stateGlobal.fullscreen.isTrue
                    ? Icons.fullscreen_exit
                    : Icons.fullscreen,
                label: stateGlobal.fullscreen.isTrue ? '전체 화면 끝내기' : '전체 화면',
                onTap: () {
                  stateGlobal.setFullscreen(!stateGlobal.fullscreen.value);
                  _close();
                },
              )),
          if (displayCount > 1)
            _menuItem(
              icon: Icons.monitor,
              label: '모니터 전환',
              trailing: '${_currentDisplay() + 1} / $displayCount',
              onTap: _nextDisplay,
            ),
          _menuItem(
            icon: Icons.upload_file_outlined,
            label: '파일 보내기',
            onTap: () {
              _close();
              connect(context, widget.id, isFileTransfer: true);
            },
          ),
          if (isWindowsPeer)
            _menuItem(
              icon: Icons.keyboard_outlined,
              label: 'Ctrl+Alt+Del 보내기',
              onTap: () {
                _close();
                bind.sessionCtrlAltDel(sessionId: _ffi.sessionId);
              },
            ),
          _menuItem(
            icon: Icons.tune,
            label: '화질',
            trailing: _kQualityLabels[_quality] ?? '사용자 지정',
            onTap: _nextQuality,
          ),
          Obx(() => _menuItem(
                icon: Icons.handyman_outlined,
                label: nauShowLegacyToolbar.isTrue ? '고급 도구 숨기기' : '고급 도구 보기',
                onTap: () {
                  nauShowLegacyToolbar.toggle();
                  _close();
                },
              )),
          Container(
            height: 1,
            margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            color: NauColors.panelBorder,
          ),
          _menuItem(
            icon: Icons.logout,
            label: '연결 끊기',
            color: NauColors.danger,
            weight: FontWeight.w700,
            onTap: () {
              _close();
              clientClose(_ffi.sessionId, _ffi);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatus() {
    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: _open || _hover || _statusVisible ? 1 : 0,
        duration: const Duration(milliseconds: 250),
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: NauColors.panel,
            border: Border.all(color: NauColors.panelBorder),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_peerName(),
                  style: nauText(size: 13, weight: FontWeight.w700)),
              Container(
                width: 1,
                height: 14,
                margin: const EdgeInsets.symmetric(horizontal: 10),
                color: NauColors.fieldBorder,
              ),
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                    color: NauColors.online, shape: BoxShape.circle),
              ),
              const SizedBox(width: 7),
              _buildConnectionLabel(),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (_ffi.ffiModel.pi.isSet.isFalse) return const Offstage();
      return Stack(
        children: [
          Positioned(
            top: 16,
            left: 0,
            right: 0,
            child: Center(child: _buildStatus()),
          ),
          Positioned(
            top: 16,
            left: 16,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              onEnter: (_) => setState(() => _hover = true),
              onExit: (_) => setState(() => _hover = false),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Tooltip(
                    message: _open ? '메뉴 닫기' : '메뉴 열기',
                    child: AnimatedOpacity(
                      opacity: _open || _hover ? 1 : 0.55,
                      duration: const Duration(milliseconds: 150),
                      child: Material(
                        color: NauColors.accent,
                        shape: const CircleBorder(
                            side: BorderSide(color: NauColors.fieldBorder)),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: _toggleMenu,
                          child: const SizedBox(
                            width: 48,
                            height: 48,
                            child: Icon(Icons.desktop_windows_outlined,
                                size: 24, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (_open) ...[
                    const SizedBox(height: 12),
                    _buildMenu(),
                  ],
                ],
              ),
            ),
          ),
        ],
      );
    });
  }
}
