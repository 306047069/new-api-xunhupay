@echo off
chcp 65001 >nul
set PATH=c:\newapi\tools\go\bin;c:\newapi\tools\node;%PATH%
set GOPROXY=https://goproxy.cn,direct
set GO111MODULE=on

echo [1/7] 清理 npm 缓存...
npm cache clean --force

echo [2/7] 清理 default 前端...
cd /d "%~dp0web\default"
if exist node_modules rmdir /s /q node_modules
if exist package-lock.json del /f /q package-lock.json

echo [3/7] 安装 default 依赖 ^(使用 legacy-peer-deps^)...
call npm install --legacy-peer-deps
if errorlevel 1 (
    echo [ERROR] default npm install 失败
    pause
    exit /b 1
)

echo [4/7] 构建 default 前端...
call npm run build
if errorlevel 1 (
    echo [ERROR] default build 失败
    pause
    exit /b 1
)

echo [5/7] 清理并构建 classic 前端...
cd /d "%~dp0web\classic"
if exist node_modules rmdir /s /q node_modules
if exist package-lock.json del /f /q package-lock.json
call npm install --legacy-peer-deps
if errorlevel 1 (
    echo [ERROR] classic npm install 失败
    pause
    exit /b 1
)
call npm run build
if errorlevel 1 (
    echo [ERROR] classic build 失败
    pause
    exit /b 1
)

echo [6/7] 下载 Go 依赖...
cd /d "%~dp0"
go mod download

echo [7/7] 启动服务...
go run main.go
