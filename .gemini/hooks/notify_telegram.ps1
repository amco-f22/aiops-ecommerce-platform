# Read input from Gemini CLI (JSON)
$inputJson = $input | Out-String | ConvertFrom-Json

# Configuration
$botToken = "8287375226:AAEUuRj5oH44MLHawcUtZEG6owDxrplQY6o"
$chatId = "5393557909"

# Determine the message based on the event
$eventName = $inputJson.hook_event_name
$sessionId = $inputJson.session_id
$message = "Gemini CLI Update`n`nEvent: $eventName`nSession: $sessionId"

# Send to Telegram
$url = "https://api.telegram.org/bot$botToken/sendMessage"
$body = @{
    chat_id = $chatId
    text = $message
}

Invoke-RestMethod -Uri $url -Method Post -Body $body | Out-Null

# Hooks must output valid JSON to stdout
Write-Output "{}"
