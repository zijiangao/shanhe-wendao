param(
	[string]$GodotPath = "C:\Users\gaozi\Downloads\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe",
	[switch]$IncludeFullJourney,
	[switch]$IncludeIsolated,
	[string]$Filter = ""
)

$ErrorActionPreference = "Continue"
$repo = Split-Path -Parent $PSScriptRoot
$project = Join-Path $repo "godot"
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$logDir = Join-Path $repo "build\test-logs\$stamp"
New-Item -ItemType Directory -Force -Path $logDir | Out-Null

# Godot writes logs/caches under user:// (%APPDATA%\Godot\...). Keep that inside
# the workspace so the sandbox never blocks the engine's own log file.
$env:APPDATA = Join-Path $repo "build\godot-appdata"
New-Item -ItemType Directory -Force -Path $env:APPDATA | Out-Null

if (-not (Test-Path $GodotPath)) {
	throw "Godot console executable not found: $GodotPath"
}

$tests = Get-ChildItem (Join-Path $project "tests") -Filter "test_*.gd" |
	Sort-Object Name |
	Where-Object { $_.Name -ne "test_full_journey.gd" -or $IncludeFullJourney } |
	Where-Object { $Filter -eq "" -or $_.Name -like "*$Filter*" }

$results = @()
foreach ($test in $tests) {
	$name = $test.Name
	$source = Get-Content $test.FullName -Raw
	# Some flow tests refuse to run against the real project/saves; they expect a
	# copy named "*-tests" with an isolated APPDATA. Keep them out of the fast
	# suite and run them through the dedicated isolated pass.
	$needs_isolated = $source -match 'ends_with\("-tests"\)|ShanheWendao-iteration-tests|Use an isolated|isolated acceptance|isolated project and APPDATA|Use isolated saves'
	if ($needs_isolated -and -not $IncludeIsolated) {
		Write-Host ("SKIP " + $name + " (isolated project required)")
		continue
	}
	# Rendering tests await RenderingServer.frame_post_draw; under --headless that
	# signal never fires, so those must run with a real (hidden) window.
	$needs_render = $source -match "frame_post_draw|save_png|get_texture\(\)|_capture_"
	$outFile = Join-Path $logDir ($name + ".out")
	$errFile = Join-Path $logDir ($name + ".err")
	$argList = @()
	if (-not $needs_render) { $argList += "--headless" }
	$argList += @("--path", $project, "--script", ("res://tests/" + $name))
	Write-Host ("==> " + $name + $(if ($needs_render) { " (windowed)" } else { "" }))

	$psi = New-Object System.Diagnostics.ProcessStartInfo
	$psi.FileName = $GodotPath
	$psi.Arguments = ($argList -join " ")
	$psi.UseShellExecute = $false
	$psi.RedirectStandardOutput = $true
	$psi.RedirectStandardError = $true
	$psi.CreateNoWindow = $true
	$proc = New-Object System.Diagnostics.Process
	$proc.StartInfo = $psi
	[void]$proc.Start()
	$outTask = $proc.StandardOutput.ReadToEndAsync()
	$errTask = $proc.StandardError.ReadToEndAsync()
	$finished = $proc.WaitForExit(150000)
	if (-not $finished) {
		try { $proc.Kill() } catch {}
		$exit = 124
	} else {
		$exit = $proc.ExitCode
	}
	$text = [string]$outTask.Result + [string]$errTask.Result
	Set-Content -Path $outFile -Value $text -Encoding utf8
	$bad = $text -match "SCRIPT ERROR|Assertion failed|Parse Error|Invalid call|Cannot open"
	$ok = ($exit -eq 0) -and (-not $bad)
	$results += [pscustomobject]@{ Test = $name; Exit = $exit; Ok = $ok }
	if (-not $ok) {
		Write-Host ("FAIL " + $name + " (exit " + $exit + ")") -ForegroundColor Red
		Write-Host ($text.Trim())
	} else {
		Write-Host ("PASS " + $name) -ForegroundColor Green
	}
}

$passed = @($results | Where-Object { $_.Ok }).Count
$total = @($results).Count
Write-Host ""
Write-Host ("Passed " + $passed + " / " + $total + "  (logs: " + $logDir + ")")
if ($passed -ne $total) {
	$results | Where-Object { -not $_.Ok } | ForEach-Object { Write-Host ("  failed: " + $_.Test) }
	exit 1
}
exit 0
