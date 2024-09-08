@echo off

set DestinationFolder=".\bin"
set ExecutableName="skc.exe"
set SourceFolder="compiler"

IF NOT EXIST %DestinationFolder% (
   MKDIR %DestinationFolder%
)

PUSHD %DestinationFolder%

odin build ..\%SourceFolder% -use-separate-modules -out:%ExecutableName% -strict-style -vet-using-stmt -vet-using-param -vet-style -vet-semicolon -debug

POPD

exit /b 0
