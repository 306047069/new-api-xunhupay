# 清理并重新构建
$ErrorActionPreference = "Stop"
$env:PATH = "c:/newapi/tools/go/bin;c:/newapi/tools/node;" + $env:PATH

Write-Host "=== 清理 default 前端 ===" -ForegroundColor Yellow
Set-Location "$PSScriptRoot/web/default"
Remove-Item -Recurse -Force -ErrorAction SilentlyContinue node_modules
Remove-Item -Force -ErrorAction SilentlyContinue package-lock.json

Write-Host "=== 重新安装 default 依赖 ===" -ForegroundColor Cyan
npm install

Write-Host "=== 构建 default ===" -ForegroundColor Cyan
npm run build

Write-Host "=== 清理 classic 前端 ===" -ForegroundColor Yellow
Set-Location "$PSScriptRoot/web/classic"
Remove-Item -Recurse -Force -ErrorAction SilentlyContinue node_modules
Remove-Item -Force -ErrorAction SilentlyContinue package-lock.json

Write-Host "=== 重新安装 classic 依赖 ===" -ForegroundColor Cyan
npm install

Write-Host "=== 构建 classic ===" -ForegroundColor Cyan
npm run build

Write-Host "=== 运行后端 ===" -ForegroundColor Green
Set-Location "$PSScriptRoot"
go mod download
go run main.go
