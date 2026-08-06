# Internal API Roadmap / Lộ trình API nội bộ

## Tiếng Việt

Các nhóm hàm dự kiến tách thành module:

- UI: menu, checkbox, progress, dialogs.
- Language: localization và lựa chọn ngôn ngữ.
- Logger: TXT/JSON logs.
- Config: JSON settings và bloatware list.
- Cleanup: temp/cache/log cleanup.
- Bloatware: Appx scan/remove.
- WindowsUpdate: component cleanup và download cache.
- Repair: DISM/SFC/CHKDSK/network repair.
- Report: summary và export.
- Network/Update: download và version checking.

Trạng thái hiện tại: `src/Modules/` là scaffold; logic thực tế vẫn nằm trong engine chính.

---

## English

Planned module boundaries:

- UI: menus, checklists, progress, dialogs.
- Language: localization and language selection.
- Logger: TXT/JSON logs.
- Config: JSON settings and bloatware list.
- Cleanup: temp/cache/log cleanup.
- Bloatware: Appx scan/remove.
- WindowsUpdate: component cleanup and download cache.
- Repair: DISM/SFC/CHKDSK/network repair.
- Report: summaries and exports.
- Network/Update: downloads and version checking.

Current status: `src/Modules/` is scaffolding; production logic remains in the main engine.
