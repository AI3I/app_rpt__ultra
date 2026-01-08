<?php
/**
 * app_rpt__ultra Message Builder
 * Simple web interface for building TMS5220 voice messages
 */

// Configuration
$VOCAB_FILE = '/opt/app_rpt/lib/vocabulary.txt';
$MSGTBL_FILE = '/opt/app_rpt/lib/messagetable.txt';
$SOUNDS_DIR = '/opt/app_rpt/sounds';

// Handle AJAX requests
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    header('Content-Type: application/json');

    $action = $_POST['action'] ?? '';

    if ($action === 'load_vocabulary') {
        // Load vocabulary words
        $vocab = [];
        if (file_exists($VOCAB_FILE)) {
            $lines = file($VOCAB_FILE, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
            foreach ($lines as $line) {
                $parts = preg_split('/\s+/', $line, 3);
                if (count($parts) >= 2) {
                    $code = $parts[0];
                    $path = $parts[1];

                    // Use third column as display name if it exists, otherwise generate from filename
                    if (count($parts) >= 3) {
                        $display = $parts[2];
                    } else {
                        $word = basename($path, '.ulaw');
                        // Auto-generate: replace underscores, ALL CAPS
                        $display = str_replace('_', ' ', $word);
                        $display = strtoupper($display);
                    }

                    // Determine voice type
                    $voice = 'other';
                    if (strpos($path, '/_male/') !== false) {
                        $voice = 'male';
                    } elseif (strpos($path, '/_female/') !== false) {
                        $voice = 'female';
                    } elseif (strpos($path, '/_sndfx/') !== false) {
                        $voice = 'sndfx';
                    }

                    $vocab[] = [
                        'word' => basename($path, '.ulaw'),  // Keep original for matching
                        'display' => $display,
                        'path' => $path,
                        'voice' => $voice
                    ];
                }
            }
        }
        echo json_encode(['vocabulary' => $vocab]);
        exit;
    }

    if ($action === 'load_slots') {
        // Load message slots
        $slots = [];
        if (file_exists($MSGTBL_FILE)) {
            $lines = file($MSGTBL_FILE, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
            foreach ($lines as $line) {
                $parts = preg_split('/\s+/', $line, 2);
                if (count($parts) >= 2) {
                    $slot = $parts[0];
                    $file = $parts[1];

                    // Create proper label from file path (matching README format)
                    $basename = basename($file);

                    // Map common patterns to proper labels
                    $label_map = [
                        // IDs
                        'initial_id_1' => 'Initial ID #1',
                        'initial_id_2' => 'Initial ID #2',
                        'initial_id_3' => 'Initial ID #3',
                        'anxious_id' => 'Anxious ID',
                        'pending_id_1' => 'Pending ID #1',
                        'pending_id_2' => 'Pending ID #2',
                        'pending_id_3' => 'Pending ID #3',
                        'pending_id_4' => 'Pending ID #4',
                        'pending_id_5' => 'Pending ID #5',
                        'special_id' => 'Special ID',
                        // Tails
                        'tail_message_1' => 'Tail Message #1',
                        'tail_message_2' => 'Tail Message #2',
                        'tail_message_3' => 'Tail Message #3',
                        'tail_message_4' => 'Tail Message #4',
                        'tail_message_5' => 'Tail Message #5',
                        'tail_message_6' => 'Tail Message #6',
                        'tail_message_7' => 'Tail Message #7',
                        'tail_message_8' => 'Tail Message #8',
                        'tail_message_9' => 'Tail Message #9',
                        'weather_alert' => 'Weather Alert',
                        'severe_weather_alert' => 'Severe Weather Alert',
                        // Weather/WX
                        'temp' => 'Temperature',
                        'wind' => 'Wind Conditions',
                        'pressure' => 'Barometric Pressure',
                        'humidity' => 'Humidity',
                        'windchill' => 'Wind Chill',
                        'heatindex' => 'Heat Index',
                        'dewpt' => 'Dew Point',
                        'preciprate' => 'Precipitation Rate',
                        'preciptotal' => 'Precipitation Total',
                        'uv_warning' => 'UV Warning',
                        'wx_alert' => 'Weather Alert',
                        'wx_severe_alert' => 'Severe Weather Alert',
                        // RPT system
                        'cw_id' => 'CW ID',
                        'litz_alert' => 'LiTZ Alert',
                        'net_in_one_minute' => 'Net in 1 Minute',
                        'net_in_five_minutes' => 'Net in 5 Minutes',
                        'net_in_ten_minutes' => 'Net in 10 Minutes',
                        'net_in_fifteen_minutes' => 'Net in 15 Minutes',
                        'empty' => 'Available',
                        // Space weather
                        'space_geomag_minor' => 'Geomag Minor',
                        'space_geomag_moderate' => 'Geomag Moderate',
                        'space_geomag_strong' => 'Geomag Strong',
                        'space_radio_minor' => 'Radio Minor',
                        'space_radio_moderate' => 'Radio Moderate',
                        'space_radio_strong' => 'Radio Strong',
                        'space_solar_minor' => 'Solar Minor',
                        'space_solar_moderate' => 'Solar Moderate',
                    ];

                    // Check for bulletin boards, mailboxes, etc with numbers
                    if (preg_match('/^bulletin_board_(\d+)$/', $basename, $m)) {
                        $label = "Bulletin Board #{$m[1]}";
                    } elseif (preg_match('/^demonstration_(\d+)$/', $basename, $m)) {
                        $label = "Demonstration Msg. #{$m[1]}";
                    } elseif (preg_match('/^emergency_autodial_(\d+)$/', $basename, $m)) {
                        $label = "Emergency Auto Dialer #{$m[1]}";
                    } elseif (preg_match('/^mailbox_(\d+)$/', $basename, $m)) {
                        $label = "Mailbox #{$m[1]}";
                    } elseif (preg_match('/^available_(\d+)$/', $basename, $m)) {
                        $label = "Available #{$m[1]}";
                    } elseif (preg_match('/^rptrism(\d+)$/', $basename, $m)) {
                        $label = "Repeaterism #{$m[1]}";
                    } elseif (isset($label_map[$basename])) {
                        $label = $label_map[$basename];
                    } else {
                        // Fallback: title case with underscores replaced
                        $label = str_replace('_', ' ', $basename);
                        $label = ucwords($label);
                    }

                    // Add category emoji prefix
                    $category = '';
                    if (strpos($file, 'ids/') === 0) $category = '🎤 ';
                    elseif (strpos($file, 'tails/') === 0) $category = '📻 ';
                    elseif (strpos($file, 'custom/') === 0) $category = '⚙️ ';
                    elseif (strpos($file, 'weather/') === 0) $category = '🌦️ ';
                    elseif (strpos($file, 'wx/') === 0) $category = '🌡️ ';
                    elseif (strpos($file, 'rpt/') === 0) $category = '📡 ';

                    // Load current message from .txt file
                    $txt_file = "$SOUNDS_DIR/$file.txt";
                    $message = file_exists($txt_file) ? trim(file_get_contents($txt_file)) : '';

                    $slots[] = [
                        'slot' => $slot,
                        'file' => $file,
                        'label' => $category . $label,
                        'message' => $message
                    ];
                }
            }
        }
        echo json_encode(['slots' => $slots]);
        exit;
    }

    if ($action === 'save_message') {
        $slot = $_POST['slot'] ?? '';
        $file = $_POST['file'] ?? '';
        $message = $_POST['message'] ?? '';
        $words = json_decode($_POST['words'] ?? '[]', true);

        if (empty($slot) || empty($file)) {
            echo json_encode(['success' => false, 'error' => 'Invalid slot']);
            exit;
        }

        $ulaw_file = "$SOUNDS_DIR/$file.ulaw";
        $txt_file = "$SOUNDS_DIR/$file.txt";

        // Build .ulaw file by concatenating vocabulary files
        $ulaw_data = '';
        foreach ($words as $word_path) {
            if (file_exists($word_path)) {
                $ulaw_data .= file_get_contents($word_path);
            }
        }

        // Save files
        $success = file_put_contents($ulaw_file, $ulaw_data) !== false &&
                   file_put_contents($txt_file, $message) !== false;

        echo json_encode(['success' => $success]);
        exit;
    }
}

?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>app_rpt Message Builder</title>
    <style>
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: #1e1e1e;
            color: #d4d4d4;
            padding: 20px;
        }
        .container { max-width: 1200px; margin: 0 auto; }
        h1 {
            color: #4ec9b0;
            margin-bottom: 20px;
            font-size: 24px;
        }
        .panel {
            background: #252526;
            border: 1px solid #3c3c3c;
            border-radius: 4px;
            padding: 15px;
            margin-bottom: 15px;
        }
        .panel h2 {
            color: #569cd6;
            font-size: 16px;
            margin-bottom: 10px;
        }
        select, input[type="text"] {
            width: 100%;
            padding: 8px;
            background: #3c3c3c;
            border: 1px solid #555;
            color: #d4d4d4;
            border-radius: 4px;
            font-size: 14px;
        }
        .vocab-search {
            margin-bottom: 10px;
        }
        .vocab-grid {
            display: grid;
            grid-template-columns: repeat(auto-fill, minmax(100px, 1fr));
            gap: 5px;
            max-height: 300px;
            overflow-y: auto;
            padding: 10px;
            background: #1e1e1e;
            border-radius: 4px;
        }
        .voice-filter {
            display: flex;
            gap: 10px;
            margin-bottom: 10px;
        }
        .voice-btn {
            padding: 6px 12px;
            background: #3c3c3c;
            border: 2px solid #555;
            color: #d4d4d4;
            border-radius: 4px;
            cursor: pointer;
            font-size: 12px;
            font-weight: bold;
        }
        .voice-btn.active {
            border-color: #4ec9b0;
            background: #2a5a4d;
        }
        .voice-btn.male { border-color: #569cd6; }
        .voice-btn.male.active { background: #2d5070; border-color: #569cd6; }
        .voice-btn.female { border-color: #c586c0; }
        .voice-btn.female.active { background: #5a3859; border-color: #c586c0; }
        .voice-btn.sndfx { border-color: #dcdcaa; }
        .voice-btn.sndfx.active { background: #5a5833; border-color: #dcdcaa; }
        .vocab-word {
            padding: 6px 10px;
            background: #3c3c3c;
            border: 1px solid #555;
            border-radius: 3px;
            cursor: pointer;
            text-align: center;
            font-size: 13px;
            transition: all 0.2s;
            position: relative;
        }
        .vocab-word:hover {
            background: #4ec9b0;
            color: #000;
            border-color: #4ec9b0;
        }
        .vocab-word::after {
            content: attr(data-voice);
            position: absolute;
            top: 2px;
            right: 2px;
            font-size: 8px;
            padding: 1px 3px;
            border-radius: 2px;
            background: #1e1e1e;
            opacity: 0.7;
        }
        .vocab-word[data-voice="male"]::after { color: #569cd6; }
        .vocab-word[data-voice="female"]::after { color: #c586c0; }
        .vocab-word[data-voice="sndfx"]::after { color: #dcdcaa; }
        .message-display {
            background: #1e1e1e;
            padding: 15px;
            border-radius: 4px;
            min-height: 60px;
            font-size: 18px;
            line-height: 1.6;
        }
        .message-word {
            display: inline-block;
            margin: 3px;
            padding: 5px 10px;
            background: #3c3c3c;
            border-radius: 3px;
            cursor: pointer;
            transition: all 0.2s;
        }
        .message-word:hover {
            background: #ce9178;
        }
        .message-word.valid {
            background: #4ec9b0;
            color: #000;
        }
        .message-word.invalid {
            background: #f48771;
            color: #000;
        }
        .buttons {
            display: flex;
            gap: 10px;
            margin-top: 15px;
        }
        button {
            padding: 10px 20px;
            border: none;
            border-radius: 4px;
            cursor: pointer;
            font-size: 14px;
            font-weight: bold;
            transition: all 0.2s;
        }
        .btn-save {
            background: #4ec9b0;
            color: #000;
        }
        .btn-save:hover {
            background: #6ee7c7;
        }
        .btn-clear {
            background: #f48771;
            color: #000;
        }
        .btn-clear:hover {
            background: #ff9d88;
        }
        .btn-secondary {
            background: #569cd6;
            color: #000;
        }
        .btn-secondary:hover {
            background: #7eb6e8;
        }
        .status {
            padding: 10px;
            border-radius: 4px;
            margin-top: 10px;
            display: none;
        }
        .status.success {
            background: #4ec9b0;
            color: #000;
        }
        .status.error {
            background: #f48771;
            color: #000;
        }
        .info {
            font-size: 12px;
            color: #858585;
            margin-top: 5px;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>🎵 app_rpt Message Builder</h1>

        <div class="panel">
            <h2>Message Slot</h2>
            <select id="slotSelect">
                <option value="">Loading slots...</option>
            </select>
            <div class="info" id="slotInfo">Select a slot to begin</div>
        </div>

        <div class="panel">
            <h2>Vocabulary</h2>
            <div class="voice-filter">
                <button class="voice-btn male active" onclick="toggleVoice('male')">Male</button>
                <button class="voice-btn female active" onclick="toggleVoice('female')">Female</button>
                <button class="voice-btn sndfx active" onclick="toggleVoice('sndfx')">Sound FX</button>
            </div>
            <input type="text" id="vocabSearch" class="vocab-search" placeholder="Search vocabulary...">
            <div class="vocab-grid" id="vocabGrid">
                Loading vocabulary...
            </div>
        </div>

        <div class="panel">
            <h2>Message</h2>
            <div class="message-display" id="messageDisplay">
                Click words above to build your message
            </div>
            <div class="info">Click words to remove them</div>
            <div class="buttons">
                <button class="btn-save" onclick="saveMessage()">Save Message</button>
                <button class="btn-clear" onclick="clearMessage()">Clear</button>
            </div>
            <div class="status" id="status"></div>
        </div>
    </div>

    <script>
        let vocabulary = [];
        let slots = [];
        let currentSlot = null;
        let messageWords = [];
        let activeVoices = { male: true, female: true, sndfx: true };

        // Load vocabulary and slots on page load
        window.addEventListener('DOMContentLoaded', async () => {
            await loadVocabulary();
            await loadSlots();
        });

        async function loadVocabulary() {
            const formData = new FormData();
            formData.append('action', 'load_vocabulary');

            const response = await fetch('msgbuilder.php', {
                method: 'POST',
                body: formData
            });

            const data = await response.json();
            vocabulary = data.vocabulary;
            renderVocabulary();
        }

        async function loadSlots() {
            const formData = new FormData();
            formData.append('action', 'load_slots');

            const response = await fetch('msgbuilder.php', {
                method: 'POST',
                body: formData
            });

            const data = await response.json();
            slots = data.slots;

            const select = document.getElementById('slotSelect');
            select.innerHTML = '<option value="">Select a slot...</option>';

            slots.forEach(slot => {
                const option = document.createElement('option');
                option.value = slot.slot;
                option.textContent = `Slot ${slot.slot} - ${slot.label}`;
                option.dataset.file = slot.file;
                option.dataset.message = slot.message;
                select.appendChild(option);
            });

            select.addEventListener('change', onSlotChange);
        }

        function onSlotChange(e) {
            const option = e.target.selectedOptions[0];
            if (!option || !option.value) return;

            currentSlot = {
                slot: option.value,
                file: option.dataset.file,
                message: option.dataset.message
            };

            document.getElementById('slotInfo').textContent =
                `Current: ${currentSlot.message || '(empty)'}`;

            // Load existing message
            if (currentSlot.message) {
                messageWords = currentSlot.message.split(/\s+/).map(word => {
                    const vocab = vocabulary.find(v => v.word.toLowerCase() === word.toLowerCase());
                    return vocab ? vocab.path : null;
                }).filter(p => p);
                renderMessage();
            } else {
                clearMessage();
            }
        }

        function toggleVoice(voice) {
            activeVoices[voice] = !activeVoices[voice];
            const btn = document.querySelector(`.voice-btn.${voice}`);
            btn.classList.toggle('active');
            renderVocabulary(document.getElementById('vocabSearch').value);
        }

        function renderVocabulary(filter = '') {
            const grid = document.getElementById('vocabGrid');
            let filtered = vocabulary.filter(v => activeVoices[v.voice]);

            if (filter) {
                filtered = filtered.filter(v => v.word.toLowerCase().includes(filter.toLowerCase()));
            }

            grid.innerHTML = filtered.map(v =>
                `<div class="vocab-word" data-voice="${v.voice}" onclick="addWord('${v.path}')" title="${v.word}">${v.display}</div>`
            ).join('');
        }

        document.getElementById('vocabSearch').addEventListener('input', (e) => {
            renderVocabulary(e.target.value);
        });

        function addWord(path) {
            messageWords.push(path);
            renderMessage();
        }

        function removeWord(index) {
            messageWords.splice(index, 1);
            renderMessage();
        }

        function renderMessage() {
            const display = document.getElementById('messageDisplay');

            if (messageWords.length === 0) {
                display.innerHTML = 'Click words above to build your message';
                return;
            }

            display.innerHTML = messageWords.map((path, index) => {
                const vocab = vocabulary.find(v => v.path === path);
                const displayText = vocab?.display || vocab?.word || 'unknown';
                return `<span class="message-word valid" onclick="removeWord(${index})" title="${vocab?.word || ''}">${displayText}</span>`;
            }).join('');
        }

        function clearMessage() {
            messageWords = [];
            renderMessage();
        }

        async function saveMessage() {
            if (!currentSlot) {
                showStatus('Please select a slot first', 'error');
                return;
            }

            if (messageWords.length === 0) {
                showStatus('Message is empty', 'error');
                return;
            }

            const message = messageWords.map(path => {
                return vocabulary.find(v => v.path === path)?.word || '';
            }).join(' ');

            const formData = new FormData();
            formData.append('action', 'save_message');
            formData.append('slot', currentSlot.slot);
            formData.append('file', currentSlot.file);
            formData.append('message', message);
            formData.append('words', JSON.stringify(messageWords));

            const response = await fetch('msgbuilder.php', {
                method: 'POST',
                body: formData
            });

            const data = await response.json();

            if (data.success) {
                showStatus(`Saved message to slot ${currentSlot.slot}!`, 'success');
                currentSlot.message = message;
                document.getElementById('slotInfo').textContent = `Current: ${message}`;
            } else {
                showStatus('Failed to save message', 'error');
            }
        }

        function showStatus(message, type) {
            const status = document.getElementById('status');
            status.textContent = message;
            status.className = `status ${type}`;
            status.style.display = 'block';

            setTimeout(() => {
                status.style.display = 'none';
            }, 3000);
        }
    </script>
</body>
</html>
