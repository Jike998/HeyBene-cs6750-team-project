@echo off
setlocal

set "JAVA_HOME=D:\Android Studio\jbr"
set "ANDROID_SDK_ROOT=C:\Users\jiken\AppData\Local\Android\sdk"
set "ANDROID_HOME=C:\Users\jiken\AppData\Local\Android\sdk"
for %%I in ("%~dp0.gradle-user") do set "GRADLE_USER_HOME=%%~fI"
set "PATH=C:\src\flutter\bin;%JAVA_HOME%\bin;%PATH%"

cd /d "%~dp0"
call C:\src\flutter\bin\flutter.bat build apk --debug --suppress-analytics
