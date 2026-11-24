$g = 'C:\Users\Bekzat\Downloads\godot47\Godot_v4.7-stable_win64.exe'
$p = 'C:\Users\Bekzat\Claude\Projects\Happy\Outputs\godot-prototype'
$modes = @('council','chronicle','summary','coronation','faith')
foreach ($m in $modes) {
    Write-Output "=== $m ==="
    & $g --path $p 'res://tools/Screenshot.tscn' -- $m 2>&1 | Select-String 'saved|SCRIPT ERROR|Parse Error|error'
}
