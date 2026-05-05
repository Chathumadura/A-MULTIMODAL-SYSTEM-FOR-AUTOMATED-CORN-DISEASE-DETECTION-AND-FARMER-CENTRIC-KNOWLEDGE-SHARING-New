Write-Host "Setting up backend-yield environment..."

# Remove old environment
if (Test-Path ".venv") {
    Remove-Item -Recurse -Force .venv
}

# Create new Python 3.10 environment
py -3.10 -m venv .venv

# Activate
.\.venv\Scripts\Activate.ps1

# Upgrade pip
python -m pip install --upgrade pip

# Install dependencies
pip install -r requirements.txt

Write-Host "Setup complete. Run: uvicorn main:app --reload --port 8081"
