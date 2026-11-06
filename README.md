# NAU Remote

사내용 원격 접속 앱입니다. [RustDesk](https://github.com/rustdesk/rustdesk) 1.5.1 을 포크해
서버 주소를 내장하고 화면을 새로 만들었습니다.

- 라이선스: AGPL-3.0 (원본과 동일, `LICENCE` 참고). 원본 저작권은 RustDesk 저작자에게 있습니다.
- 원본과 다른 부분: `src/common.rs` 의 `load_nau_builtin`, `flutter/lib/nau/`, 아이콘, 빌드 설정.
- 빌드: Actions 탭에서 **NAU Remote build** 를 수동 실행하면 Windows · macOS · Android 설치 파일이 릴리스에 올라갑니다.

This is a fork of RustDesk 1.5.1 for internal use, distributed under the same AGPL-3.0 licence.
