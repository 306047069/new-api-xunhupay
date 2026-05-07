# New-API 部署脚本 (SQLite + 源码运行)
$ErrorActionPreference = "Stop"

# 1. 设置环境变量
$toolsPath = "c:/newapi/tools"
$env:PATH = "$toolsPath/go/bin;$toolsPath/node;" + $env:PATH
$env:GOPROXY = "https://goproxy.cn,direct"
$env:GO111MODULE = "on"

Write-Host "=== 验证工具 ===" -ForegroundColor Cyan
& go version
& node -v
& npm -v

# 2. 构建前端 (default)
Write-Host "=== 构建 default 前端 ===" -ForegroundColor Cyan
Set-Location "$PSScriptRoot/web/default"
& npm install
& npm run build

# 3. 构建前端 (classic)
Write-Host "=== 构建 classic 前端 ===" -ForegroundColor Cyan
Set-Location "$PSScriptRoot/web/classic"
& npm install
& npm run build

# 4. 下载 Go 依赖并运行
Write-Host "=== 下载 Go 依赖 ===" -ForegroundColor Cyan
Set-Location "$PSScriptRoot"
& go mod download

Write-Host "=== 启动 New-API 服务 ===" -ForegroundColor Green
& go run main.go
