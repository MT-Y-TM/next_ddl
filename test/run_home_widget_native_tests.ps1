param([string]$GradleCache = "$env:USERPROFILE/.gradle/caches/modules-2/files-2.1")
$ErrorActionPreference = 'Stop'
function Find-Jar([string]$RelativePath) {
    $file = Get-ChildItem (Join-Path $GradleCache $RelativePath) -Recurse -Filter '*.jar' |
        Sort-Object FullName -Descending | Select-Object -First 1
    if (!$file) { throw "Missing cached dependency: $RelativePath" }
    return $file.FullName
}
$stdlib = Find-Jar 'org.jetbrains.kotlin/kotlin-stdlib/2.2.20'
$json = Find-Jar 'org.json/json'
$annotations = Find-Jar 'org.jetbrains/annotations'
$compilerClasspath = @(
    (Find-Jar 'org.jetbrains.kotlin/kotlin-compiler-embeddable/2.2.20'),
    $stdlib,
    (Find-Jar 'org.jetbrains.kotlin/kotlin-script-runtime/2.2.20'),
    (Find-Jar 'org.jetbrains.kotlin/kotlin-reflect'),
    (Find-Jar 'org.jetbrains.kotlinx/kotlinx-coroutines-core-jvm/1.8.0'),
    $annotations
) -join [IO.Path]::PathSeparator
$root = Split-Path $PSScriptRoot -Parent
$output = Join-Path $root 'build/widget-native-tests'
New-Item -ItemType Directory -Force $output | Out-Null
$runtimeClasspath = @($output, $stdlib, $json, $annotations) -join [IO.Path]::PathSeparator
& java -cp $compilerClasspath org.jetbrains.kotlin.cli.jvm.K2JVMCompiler -no-stdlib -no-reflect `
    -classpath $runtimeClasspath -d $output `
    "$root/android/app/src/main/kotlin/com/mtytm/nextddl/next_ddl/NextDdlWidgetSnapshot.kt" `
    "$root/android/app/src/test/kotlin/com/mtytm/nextddl/next_ddl/NextDdlWidgetSelectionTest.kt"
if ($LASTEXITCODE -ne 0) { throw 'Widget Kotlin compilation failed' }
& java -cp $runtimeClasspath com.mtytm.nextddl.next_ddl.NextDdlWidgetSelectionTest
if ($LASTEXITCODE -ne 0) { throw 'Widget native contract tests failed' }
