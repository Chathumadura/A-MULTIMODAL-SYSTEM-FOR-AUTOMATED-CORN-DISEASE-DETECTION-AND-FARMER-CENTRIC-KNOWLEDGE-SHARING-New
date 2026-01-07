Scripts to auto-start backend and frontend (Windows PowerShell)

- `start-backend.ps1` — opens a new PowerShell window and runs the backend uvicorn server from `backend/venv`.
- `start-frontend.ps1 [API_BASE_URL] [device]` — opens a new PowerShell window and runs `flutter run` for the frontend. Default API is `http://10.161.164.34:8000` and default device is `windows`.
- `run-all.ps1` — launches both helpers in separate windows.

Notes:
- Ensure `venv` exists and dependencies are installed in `backend` before using `start-backend.ps1`.
- Allow port `8000` in Windows Firewall when testing from a physical phone.

Example usage from repo root:
```powershell
.\
.\scripts\run-all.ps1
```
