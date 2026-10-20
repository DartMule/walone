    const owner = String(targetOwnerID), id = String(targetID);
    const tracks = [], seen = new Set();
    window.__waloneVKCancelled = false;
    let unavailable = 0;
    function clean(text) { const e = document.createElement('textarea'); e.innerHTML = String(text || ''); return e.value.trim(); }
    function add(raw) {
        const trackID = String(Array.isArray(raw) ? raw[0] : raw?.id);
        const ownerID = String(Array.isArray(raw) ? raw[1] : raw?.owner_id);
        if (!/^-?\d+$/.test(ownerID) || !/^\d+$/.test(trackID)) { unavailable++; return; }
        const sourceID = `vk:${ownerID}_${trackID}`;
        if (seen.has(sourceID)) return;
        seen.add(sourceID);
        tracks.push({ownerID, id: trackID, raw,
            title: clean(Array.isArray(raw) ? raw[3] : raw.title),
            artist: clean(Array.isArray(raw) ? raw[4] : raw.artist),
            duration: Number(Array.isArray(raw) ? raw[5] : raw.duration) || 0});
    }
    if (!isPlaylist) {
        for (let attempt = 0; attempt < 40; attempt++) {
            if (window.__waloneVKCancelled) return {reason: 'cancelled'};
            for (const element of document.querySelectorAll('[data-audio]')) {
                try {
                    const raw = JSON.parse(element.getAttribute('data-audio'));
                    if (String(Array.isArray(raw) ? raw[0] : raw.id) === id &&
                        String(Array.isArray(raw) ? raw[1] : raw.owner_id) === owner) { add(raw); return {tracks, name: '', unavailable}; }
                } catch (_) {}
            }
            await new Promise(resolve => setTimeout(resolve, 250));
        }
        return {reason: 'missing'};
    }
    // Mobile VK returns playlist pages separately from the visible HTML.
    if (!location.hostname.startsWith('m.')) return {reason: 'mobile'};
    let offset = 0, name = '';
    for (let page = 0; page < 1000; page++) {
        if (window.__waloneVKCancelled) return {reason: 'cancelled'};
        const params = new URLSearchParams({act: 'load_section', type: 'playlist', owner_id: owner,
            playlist_id: id, offset: String(offset), is_loading_all: '1', access_hash: accessKey, access_key: accessKey});
        const controller = new AbortController();
        window.__waloneVKRequest = controller;
        const timer = setTimeout(() => controller.abort(), 20000);
        let section;
        try {
            const response = await fetch('/audio', {method: 'POST', credentials: 'same-origin',
                headers: {'X-Requested-With': 'XMLHttpRequest'}, body: params, signal: controller.signal});
            if (!response.ok) return {reason: 'access'};
            const body = JSON.parse((await response.text()).replace(/^<!--/, ''));
            section = body.data?.[0];
        } catch (_) { return {reason: 'access'}; }
        finally { clearTimeout(timer); window.__waloneVKRequest = null; }
        if (!section || !Array.isArray(section.list)) return {reason: 'access'};
        if (!name) name = clean(section.title || section.name || '');
        const previousCount = tracks.length;
        section.list.forEach(add);
        const more = section.hasMore && section.hasMore !== '0';
        if (!more) {
            const heading = document.querySelector('.au_playlist_title, .audio_playlist_title, [data-playlist-title], h1');
            const pageTitle = clean(document.title).replace(/\s*[|—–]\s*ВКонтакте.*$/, '');
            return {tracks, unavailable, name: name || clean(heading?.textContent) || pageTitle || 'Плейлист VK'};
        }
        if (!section.list.length || tracks.length === previousCount) return {reason: 'pagination'};
        offset += section.list.length;
        await new Promise(resolve => setTimeout(resolve, 1500));
    }
    return {reason: 'pagination'};
