# Education Deploy - corrected repository

Repository này sử dụng **đúng bản Deploy-Education.ps1 hiện tại người dùng vừa cung cấp**, không dùng bản cũ trong Library.

## Bản release hiện tại

- Build: `v6 - fixed-drive selection + multi-signal login readiness`
- Size: `70925` bytes
- SHA256: `C74085F6D27B9B5488CB14C0152FEA302D46DF7CBB48AC0970967FDDC0D2109B`
- Manifest ready: `true`

## Cấu trúc

```text
education-deploy/
├─ bootstrap.cmd
├─ RUN-ENDPOINT.txt
├─ release/
│  ├─ Deploy-Education.ps1
│  └─ version.json
├─ tools/
│  ├─ Publish-Release.ps1
│  └─ Test-Release.ps1
├─ .gitattributes
├─ .gitignore
└─ README.md
```

Không tạo nhiều file `Deploy-Education-v2.ps1`, `v3.ps1` trong `release/`.
Mỗi lần nâng cấp chỉ ghi đè `release/Deploy-Education.ps1`; Git giữ lịch sử.

## Mỗi lần publish

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\Publish-Release.ps1 -Version 1.0.1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\Test-Release.ps1
```

Sau đó commit:

```text
git add release/Deploy-Education.ps1 release/version.json
git commit -m "release 1.0.1"
git push
```

`Publish-Release.ps1` cập nhật:
- version;
- build comment nếu có;
- file size;
- SHA256;
- publishedAt.

Endpoint kiểm cả **size + SHA256** trước khi chạy.

## Lưu ý GitHub public

Bản script hiện tại có Google Drive API key đã cấu hình trực tiếp trong file.
Nếu repo GitHub là public thì key đó cũng sẽ public.

Nếu vẫn dùng mô hình repo public để endpoint không cần GitHub token, nên ít nhất:
- giới hạn API key chỉ cho Google Drive API;
- theo dõi quota;
- xoay key nếu nghi bị lạm dụng.

Không đưa tài khoản/mật khẩu giáo viên, cookie hoặc session vào repo.
