# fix-vs.ps1
# This script replaces any hardcoded Visual Studio path in LLVMExports.cmake
# with the literal string $ENV{VSINSTALLDIR} for portability across systems.
# Usage: Run this script in PowerShell after LLVM installation, inside the LLVM folder.
# This is a fix for https://github.com/hylo-lang/llvm-build/issues/15 and https://discourse.llvm.org/t/llvm-assumes-specific-visual-studio-installation-after-build/79857/4

# Path to the LLVMExports.cmake file (relative to LLVM install root)
$llvmExportsPath = "./lib/cmake/llvm/LLVMExports.cmake"

# Check if the LLVMExports.cmake file exists
if (-Not (Test-Path $llvmExportsPath)) {
    Write-Error "The file $llvmExportsPath does not exist."
    exit 1
}

# Regex to match typical VS install paths (e.g., C:/Program Files/Microsoft Visual Studio/2022/Enterprise/)
$vsPathPattern = "C:/Program Files/Microsoft Visual Studio/[0-9]+/[A-Za-z]+/"

# Read the contents of the LLVMExports.cmake file
$fileContent = Get-Content -Path $llvmExportsPath -Raw

# Replace all matching VS paths with the literal $ENV{VSINSTALLDIR}
$newContent = [regex]::Replace($fileContent, $vsPathPattern, '$ENV{VSINSTALLDIR}/')

if ($fileContent -eq $newContent) {
    Write-Output "No replacements were made in $llvmExportsPath."
    exit 1
} else {
    Set-Content -Path $llvmExportsPath -Value $newContent
    Write-Output "Patched $llvmExportsPath to use $ENV{VSINSTALLDIR} instead of hardcoded VS path."
}
