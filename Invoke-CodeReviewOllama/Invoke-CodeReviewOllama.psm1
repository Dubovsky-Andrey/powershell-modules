function Invoke-CodeReviewOllama {
    param (
        [string]$Path,
        [string]$Model
    )

    if (-Not (Test-Path $Path)) {
        Write-Error "Path '$Path' does not exist."
        return
    }

    $extensions = @(".py", ".yaml", ".yml", ".json", ".sh", ".tf", ".txt", ".md")
    $allContent = ""

    Get-ChildItem -Path $Path -Recurse -File | Where-Object {
        $extensions -contains $_.Extension
    } | ForEach-Object {
        try {
            $fileContent = Get-Content -Path $_.FullName -Raw -Encoding UTF8
            $allContent += "`n`n===== Filename: $($_.FullName) =====`n`n$fileContent"
        } catch {
            Write-Warning "Unable to read file: $($_.FullName)"
        }
    }

    if (-not $allContent) {
        Write-Warning "No matching files found in '$Path'"
        return
    }

    $prompt = @"
Review and critique the following combined set of files and their code. 
Provide comprehensive feedback, identify common issues, potential improvements, and general best-practice recommendations.

$allContent
"@

    try {
        $jsonBody = @{
            model = $Model
            prompt = $prompt
            stream = $false
        } | ConvertTo-Json -Depth 3

        $response = Invoke-RestMethod -Uri "http://localhost:11434/api/generate" `
            -Method POST `
            -Body $jsonBody `
            -ContentType "application/json"

        Write-Host "`n===== Comprehensive Feedback =====`n"
        $response.response
    } catch {
        Write-Error "Failed to communicate with Ollama: $_"
    }
}
