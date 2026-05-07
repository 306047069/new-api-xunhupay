# New-API 构建并运行脚本（含虎皮椒支付）
$ErrorActionPreference = "Stop"
$env:PATH = "c:/newapi/tools/go/bin;c:/newapi/tools/node;" + $env:PATH
$env:GOPROXY = "https://goproxy.cn,direct"
$env:GO111MODULE = "on"

Write-Host "=== 环境检查 ===" -ForegroundColor Cyan
& go version
& node -v
& npm -v

# 只构建 default 前端（classic 可选）
$defaultDist = "c:/newapi/new-api-main/web/default/dist"
if (-not (Test-Path $defaultDist)) {
    Write-Host "=== 构建 default 前端 ===" -ForegroundColor Cyan
    Set-Location "c:/newapi/new-api-main/web/default"
    if (Test-Path "node_modules") {
        Remove-Item -Recurse -Force "node_modules"
    }
    if (Test-Path "package-lock.json") {
        Remove-Item -Force "package-lock.json"
    }
    & npm install --legacy-peer-deps
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[ERROR] npm install 失败，尝试跳过可选依赖..." -ForegroundColor Red
        & npm install --legacy-peer-deps --no-optional
    }
    & npm run build
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[ERROR] 前端构建失败" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "=== default 前端已构建，跳过 ===" -ForegroundColor Green
}

# classic 前端（如果存在源码但没有 dist）
$classicDist = "c:/newapi/new-api-main/web/classic/dist"
if (-not (Test-Path $classicDist)) {
    Write-Host "=== 构建 classic 前端 ===" -ForegroundColor Cyan
    Set-Location "c:/newapi/new-api-main/web/classic"
    if (Test-Path "node_modules") {
        Remove-Item -Recurse -Force "node_modules"
    }
    if (Test-Path "package-lock.json") {
        Remove-Item -Force "package-lock.json"
    }
    & npm install --legacy-peer-deps
    & npm run build
} else {
    Write-Host "=== classic 前端已构建，跳过 ===" -ForegroundColor Green
}

# 运行后端
Write-Host "=== 下载 Go 依赖 ===" -ForegroundColor Cyan
Set-Location "c:/newapi/new-api-main"
& go mod download

Write-Host "=== 启动 New-API 服务 ===" -ForegroundColor Green
Write-Host "访问地址: http://localhost:3000"
Write-Host "默认账号: root / 123456"
& go run main.go
