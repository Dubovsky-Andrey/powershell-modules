function Invoke-OllamaCodeReview {
    [CmdletBinding()]
    param (
        [string]$Path,
        [string]$Model = "gemma3:27b-it-q4_K_M"
    )
    [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false, $false)

    # 1. Подставляем текущий каталог, если путь не указан
    if ([string]::IsNullOrWhiteSpace($Path)) {
        $Path = (Get-Location).Path
    }

    if (-not (Test-Path $Path)) {
        Write-Error "Path '$Path' does not exist."
        return
    }

    # 2. Собираем содержимое файлов нужных расширений
    $extensions = @(".py", ".ps1", ".psm1", ".yaml", ".yml", ".json", ".sh", ".tf", ".txt", ".md")
    $allContent = ""
    Get-ChildItem -Path $Path -Recurse -File |
        Where-Object { $extensions -contains $_.Extension } |
        ForEach-Object {
            try {
                $text = Get-Content -Path $_.FullName -Raw -Encoding UTF8
                $allContent += "`n`n===== Filename: $($_.FullName) =====`n`n$text"
            } catch {
                Write-Warning "Unable to read file: $($_.FullName)"
            }
        }

    if (-not $allContent) {
        Write-Warning "No matching files found in '$Path'"
        return
    }

    # 3. Формируем промпт для Ollama
    $prompt = @"
Просмотрите и проанализируйте следующие файлы и их код. Если вы обнаружите проблемы, укажите их точно, предложите исправления и улучшения. Приводите только конкретные рекомендации по улучшению качества кода, базируясь на передовых практиках. Критикуйте строго и профессионально, как если бы вы были техническим лидером, проводящим финальную ревизию перед продакшеном.

Не давайте общих рассуждений или похвалы — фокус только на ошибках, слабых местах, недочётах, анти-паттернах и потенциальных улучшениях. Выражайтесь кратко и по существу.

Ты можешь предлагать новые идеи которые я упустил или о которых я не подумал.

Форматируйте свои советы в виде:

в файле

`<полный путь к файлу>`

Cтроках
[ номер 35-45 ]

Instead of:

`<плохой пример>`

Use:
`<хороший пример>`

или:

Problem:
`<описание проблемы>`

Suggestion:
`<предложение исправления>`

На что предлогаешь исправить
`<.....>`

Дополнительные улучшения:
(обясни зачем эти улушчения)
`<код улучшения>`

Начните анализ ниже:

$allContent
"@

    # 4. Собираем JSON в файл body.json
    $body = @{
        model  = $Model
        prompt = $prompt
        stream = $true
    }
    $jsonBody = $body | ConvertTo-Json -Depth 5
    $tempFile = Join-Path $env:TEMP "ollama_body.json"
    $jsonBody | Set-Content -Path $tempFile -Encoding UTF8

    # 5. Вызываем curl.exe с отключённым прогресс-баром и стримим ответ
    Write-Host "`n===== Real-time Feedback from Ollama ($Model) =====`n"
    & curl.exe --no-progress-meter -s -N `
        -X POST "http://localhost:11434/api/generate" `
        -H "Content-Type: application/json" `
        -H "Accept: text/event-stream" `
        --data-binary "@$tempFile" |
        ForEach-Object {
            try {
                $obj = $_ | ConvertFrom-Json
                if ($obj.response) {
                    Write-Host -NoNewline $obj.response
                }
            } catch {
                # Пропускаем строки, которые не являются JSON
            }
        }

    # 6. Удаляем временный файл
    Remove-Item $tempFile -ErrorAction SilentlyContinue
}
