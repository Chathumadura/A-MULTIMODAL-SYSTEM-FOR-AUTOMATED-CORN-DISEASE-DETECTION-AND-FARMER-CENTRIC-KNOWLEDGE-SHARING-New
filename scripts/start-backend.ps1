<#
.\scripts\start-backend.ps1
Starts the FastAPI backend in a new PowerShell window using the repository's venv.
Usage: Right-click -> Run with PowerShell, or from PS: .\scripts\start-backend.ps1
#>

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
$backendPath = Join-Path $scriptRoot "..\backend" | Resolve-Path -Relative

$cmd = "cd '$backendPath'; .\venv\Scripts\python.exe -m uvicorn app:app --host 0.0.0.0 --port 8000 --reload"

Start-Process -FilePath powershell -ArgumentList @('-NoExit','-NoProfile','-Command',$cmd)
