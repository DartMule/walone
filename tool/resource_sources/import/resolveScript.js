    // Web audio URL format reference: python273/vk_api, audio_url_decoder.py (Apache-2.0).
    function decodeAudioURL(source) {
        const alphabet = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMN0PQRSTUVWXYZO123456789+/=';
        const base64 = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=';
        function unpack(value) {
            return atob(Array.from(value, c => base64[alphabet.indexOf(c)] || c).join(''));
        }
        function shuffle(value, seed) {
            const chars = Array.from(value), n = chars.length, positions = [];
            if (!n) return value;
            for (let i = n - 1; i >= 0; i--) {
                seed = ((n * (i + 1)) ^ (seed + i)) % n;
                positions[i] = seed;
            }
            for (let i = 1; i < n; i++) {
                const j = positions[n - 1 - i];
                [chars[i], chars[j]] = [chars[j], chars[i]];
            }
            return chars.join('');
        }
        try {
            if (source.length > 32768) return null;
            const parts = source.split('?extra=')[1].split('#');
            let value = unpack(parts[0]);
            const operations = unpack(parts[1]).split('\t').reverse();
            for (const operation of operations) {
                const [mode, argument] = operation.split('\v');
                switch (mode) {
                case 'v': value = Array.from(value).reverse().join(''); break;
                case 'r': {
                    const shift = Number(argument);
                    if (!Number.isInteger(shift)) return null;
                    value = Array.from(value, c => {
                        const index = alphabet.indexOf(c);
                        return index < 0 ? c : alphabet[((index - shift) % alphabet.length + alphabet.length) % alphabet.length];
                    }).join('');
                    break;
                }
                case 'x':
                    if (!argument) return null;
                    value = Array.from(value, c => String.fromCharCode(c.charCodeAt(0) ^ argument.charCodeAt(0))).join('');
                    break;
                case 's':
                case 'i': {
                    let seed = Number(argument);
                    if (!Number.isInteger(seed)) return null;
                    if (mode === 'i') {
                        const userID = Number(window.vk?.id || (document.cookie.match(/(?:^|;\s*)remixmid=(\d+)/) || [])[1]);
                        if (!Number.isSafeInteger(userID) || userID <= 0) return null;
                        seed ^= userID;
                    }
                    value = shuffle(value, seed);
                    break;
                }
                default: return null;
                }
            }
            return value.startsWith('https://') ? value : null;
        } catch (_) { return null; }
    }
    const owner = Number(typeof targetOwnerID === 'undefined' ? 180726984 : targetOwnerID);
    const id = Number(typeof targetTrackID === 'undefined' ? 456242582 : targetTrackID);
    function describe(track, url) {
        function clean(text) { const e = document.createElement('textarea'); e.innerHTML = String(text || ''); return e.value.trim(); }
        return {url, sourceID: `vk:${owner}_${id}`,
            title: clean(Array.isArray(track) ? track[3] : track.title),
            artist: clean(Array.isArray(track) ? track[4] : track.artist),
            duration: Number(Array.isArray(track) ? track[5] : track.duration) || 0};
    }
    function matches(a) {
        return Array.isArray(a) ? Number(a[0]) === id && Number(a[1]) === owner
            : a && Number(a.id) === id && Number(a.owner_id) === owner;
    }
    function find(value, depth = 0) {
        if (!value || depth > 8) return null;
        if (matches(value)) return value;
        if (typeof value === 'object') {
            for (const item of Object.values(value)) {
                const found = find(item, depth + 1);
                if (found) return found;
            }
        }
        return null;
    }
    let current = null;
    try { current = window.getAudioPlayer?.()?.getCurrentAudio?.(); } catch (_) {}
    if (matches(current)) {
        const media = Array.from(document.querySelectorAll('audio')).find(e => !e.paused && e.currentSrc.startsWith('https://'));
        if (media) return describe(current, media.currentSrc);
    }
    const supplied = typeof rawTrack === 'undefined' ? null : rawTrack;
    let track = matches(supplied) ? supplied : (matches(current) ? current : null);
    for (const element of track ? [] : document.querySelectorAll('[data-audio]')) {
        try {
            const value = JSON.parse(element.getAttribute('data-audio'));
            if (matches(value)) { track = value; break; }
        } catch (_) {}
    }
    if (!track) return {reason: 'missing'};
    const hashes = Array.isArray(track) ? String(track[13] || '').split('/') : [];
    const actionHash = Array.isArray(track) ? hashes[2] : track.actionHash;
    const urlHash = Array.isArray(track) ? hashes[5] : track.urlHash;
    if (actionHash && urlHash) {
        const mobile = location.hostname.startsWith('m.');
        const params = new URLSearchParams({act: 'reload_audio', ids: `${owner}_${id}_${actionHash}_${urlHash}`});
        if (!mobile) params.set('al', '1');
        const controller = new AbortController();
        const timer = setTimeout(() => controller.abort(), 15000);
        try {
            const response = await fetch(mobile ? '/audio' : '/al_audio.php', {
                method: 'POST', credentials: 'same-origin', signal: controller.signal,
                headers: {'X-Requested-With': 'XMLHttpRequest'}, body: params
            });
            if (response.ok) {
                const text = (await response.text()).replace(/^<!--/, '');
                const loaded = find(JSON.parse(text));
                if (loaded) track = loaded;
            }
        } catch (_) {} finally { clearTimeout(timer); }
    }
    let url = Array.isArray(track) ? track[2] : track.url;
    if (typeof url !== 'string' || !url) return {reason: 'unavailable'};
    if (url.includes('audio_api_unavailable')) {
        url = decodeAudioURL(url);
        if (!url) return {reason: 'encoded'};
    }
    return url.startsWith('https://') ? describe(track, url) : {reason: 'unavailable'};
