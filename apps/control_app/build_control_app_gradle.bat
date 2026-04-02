@echo off
cd /d "%~dp0android"
set "JAVA_HOME=D:\Android Studio\jbr"
set "ANDROID_SDK_ROOT=C:\Users\jiken\AppData\Local\Android\sdk"
set "ANDROID_HOME=C:\Users\jiken\AppData\Local\Android\sdk"
set "PATH=%JAVA_HOME%\bin;%PATH%"
for %%I in ("%~dp0.gradle-user") do set "GRADLE_USER_HOME=%%~fI"
call gradlew.bat --no-daemon --console=plain assembleDebug
