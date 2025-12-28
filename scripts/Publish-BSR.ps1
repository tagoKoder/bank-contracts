param(
  [Parameter(Mandatory=$true)][string]$Org,
  [Parameter(Mandatory=$false)][string]$Repo = "bank",
  [Parameter(Mandatory=$false)][ValidateSet("public","private")][string]$Visibility = "public",
  [Parameter(Mandatory=$false)][string]$Label = "v0.1.0"
)

$ErrorActionPreference = "Stop"

# Load .env
$envFile = Join-Path $PSScriptRoot "..\.env"
if (Test-Path $envFile) {
  Get-Content $envFile | ForEach-Object {
    if ($_ -match "^\s*([^#][^=]+)=(.+)$") {
      $name = $matches[1].Trim()
      $value = $matches[2].Trim().Trim('"')
      [Environment]::SetEnvironmentVariable($name, $value)
    }
  }
}

function Assert-Cmd($cmd) {
  if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
    throw "No se encontró '$cmd' en PATH."
  }
}

Assert-Cmd "buf"

if (-not $env:BUF_TOKEN) {
  throw "Falta BUF_TOKEN en el entorno."
}

$module = "buf.build/$Org/$Repo"
Write-Host "==> Login BSR ($module)"
$env:BUF_TOKEN | buf registry login buf.build --token-stdin
if ($LASTEXITCODE -ne 0) { throw "buf registry login falló." }

Write-Host "==> Lint"
buf lint
if ($LASTEXITCODE -ne 0) { throw "buf lint falló. Corrige los .proto o ajusta buf.yaml." }

Write-Host "==> Breaking (contra registry default)"
try {
  buf breaking --against-registry
  if ($LASTEXITCODE -ne 0) { throw "breaking violations" }
} catch {
  Write-Host "Aviso: breaking no pudo ejecutarse (primer push o repo inexistente). Continuando..."
}

Write-Host "==> Push ($Visibility) labels: main, $Label"
buf push --create --create-visibility $Visibility --label main --label $Label
if ($LASTEXITCODE -ne 0) { throw "buf push falló." }

Write-Host "DONE."
