@echo off
chcp 65001 >nul
echo ==========================================
echo  New-API Windows Server 部署脚本
echo ==========================================

set PATH=c:\newapi\tools\go\bin;c:\newapi\tools\node;%PATH%
set GOPROXY=https://goproxy.cn,direct
set GO111MODULE=on
set NODE_OPTIONS=--no-warnings

echo [1/7] 检查长路径支持...
reg query "HKLM\SYSTEM\CurrentControlSet\Control\FileSystem" /v LongPathsEnabled | find "0x1" >nul
if errorlevel 1 (
    echo [WARN] 长路径支持未生效，尝试注册表修复...
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\FileSystem" /v LongPathsEnabled /t REG_DWORD /d 1 /f >nul
    echo [INFO] 注册表已修改，如后续仍报错请重启服务器后再运行
)

echo [2/7] 清理 npm 缓存和旧依赖...
call npm cache clean --force >nul 2>&1

cd /d "%~dp0web\default"
if exist node_modules rmdir /s /q node_modules 2>nul
if exist package-lock.json del /f /q package-lock.json 2>nul

echo [3/7] 安装 default 前端依赖 ^(使用 legacy-peer-deps 绕过版本冲突^)...
call npm install --legacy-peer-deps 2>&1
if errorlevel 1 (
    echo [ERROR] default npm install 失败，尝试跳过可选依赖...
    call npm install --legacy-peer-deps --no-optional 2>&1
    if errorlevel 1 (
        echo [FATAL] 安装失败，请检查网络或尝试重启服务器后重试
        pause
        exit /b 1
    )
)

echo [4/7] 构建 default 前端...
call npm run build 2>&1
if errorlevel 1 (
    echo [ERROR] default build 失败
    pause
    exit /b 1
)

echo [5/7] 构建 classic 前端...
cd /d "%~dp0web\classic"
if exist node_modules rmdir /s /q node_modules 2>nul
if exist package-lock.json del /f /q package-lock.json 2>nul
call npm install --legacy-peer-deps 2>&1
if errorlevel 1 (
    call npm install --legacy-peer-deps --no-optional 2>&1
)
call npm run build 2>&1

echo [6/7] 下载 Go 依赖...
cd /d "%~dp0"
go mod download

echo [7/7] 启动 New-API 服务...
echo 访问地址: http://localhost:3000
echo 默认账号: root / 123456
go run main.go
