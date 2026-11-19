# Быстрый веб-экспорт для CrazyGames + локальный сервер для проверки.
#   powershell -ExecutionPolicy Bypass -File tools/export_web.ps1            экспорт, сервер, браузер
#   powershell -ExecutionPolicy Bypass -File tools/export_web.ps1 -NoExport  только сервер (без пересборки)
#   powershell -ExecutionPolicy Bypass -File tools/export_web.ps1 -NoServe   только экспорт
# Либо двойной клик по tools/export_web.bat.
# Экспорт идёт по пресету "CrazyGames" из export_presets.cfg (сам файл скрипт не меняет).
# Реклама/SDK CrazyGames на localhost работают в тестовом режиме (docs/crazygames-requirements.md §4).
param(
	[switch]$NoExport,
	[switch]$NoServe,
	[int]$Port = 8060,
	[string]$Godot = "C:\Users\User\Desktop\Godot_v4.7.2-stable_win64_console.exe"
)
$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [Text.Encoding]::UTF8
$project = Split-Path -Parent $PSScriptRoot
$out = Join-Path $project "export\CrazyGames"

if (-not $NoExport) {
	# Открытый редактор держит проект и может помешать экспорту: предупреждаем, но не убиваем.
	$editors = Get-Process Godot* -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowTitle -like "*tank-game*" }
	if ($editors) { Write-Warning "Открыт редактор проекта - сохраните сцены; экспорт возьмёт то, что на диске." }
	New-Item -ItemType Directory -Force $out | Out-Null
	Get-ChildItem $out -Filter *.br -ErrorAction SilentlyContinue | Remove-Item -Force  # пересоберутся
	Write-Host "Экспорт 'CrazyGames' -> $out" -ForegroundColor Cyan
	$ErrorActionPreference = "Continue"  # Godot пишет предупреждения в stderr - это не ошибка
	& $Godot --headless --path $project --export-release "CrazyGames" (Join-Path $out "index.html") 2>&1 |
		Where-Object { $_ -match "ERROR|WARNING|WebBuildCompressor|DONE.*savepack" }
	if (-not (Test-Path (Join-Path $out "index.pck"))) { throw "Экспорт не создал index.pck - смотрите вывод выше." }
	$bytes = (Get-ChildItem $out -Filter *.br | Measure-Object Length -Sum).Sum
	"{0:N1} MB в .br (лимит CrazyGames для начальной загрузки: 20 MB), файлов: {1}" -f ($bytes / 1MB), (Get-ChildItem $out -File).Count | Write-Host
}

if (-not $NoServe) {
	$url = "http://localhost:$Port/index.html"
	Write-Host "Сервер: $url   (Ctrl+C - остановить)" -ForegroundColor Green
	Start-Process $url
	python -m http.server $Port --bind 127.0.0.1 --directory $out
}
