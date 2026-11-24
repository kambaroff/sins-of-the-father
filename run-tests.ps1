# One-shot compact regression. Runs every headless test suite and prints ONLY the
# one-line verdict from each (plus the deck-load line once), so a full regression
# costs one command and ~8 lines instead of six processes and six logs.
#   powershell -ExecutionPolicy Bypass -File .\run-tests.ps1

$godot = "C:\Users\Bekzat\Downloads\godot47\Godot_v4.7-stable_win64.exe"
$proj  = "C:\Users\Bekzat\Claude\Projects\Happy\Outputs\godot-prototype"
$suites = @("TestPlaystyles","TestThreats","TestTrade","TestMeta","TestTraits","TestEscalation","TestCardRender")

$deckShown = $false
foreach ($s in $suites) {
  $out = & $godot --headless --path $proj ("res://tests/$s.tscn") --quit-after 400 2>&1 | Out-String
  if (-not $deckShown) {
    $deck = ($out -split "`n" | Select-String -Pattern 'ContentDB\]' | Select-Object -First 1)
    if ($deck) { ("{0}" -f ($deck -replace '\s+',' ').Trim()); $deckShown = $true }
  }
  $verdict = ($out -split "`n" | Select-String -Pattern '\[TEST|Assertion failed|SCRIPT ERROR' | Select-Object -First 1)
  if (-not $verdict) { $verdict = "no verdict - inspect $s" }
  "{0,-15} {1}" -f $s, (($verdict -replace '\s+',' ').Trim())
}
