$path = Resolve-Path $args[0]
$text = [System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8)
$enc = New-Object System.Text.UTF8Encoding($true)
[System.IO.File]::WriteAllText($path, $text, $enc)
Write-Host "BOM added to $path"
