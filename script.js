;(function () {
    if (window.__julus_coords_init__) return;
    window.__julus_coords_init__ = true;

    async function copyToClipboard(str) {
        try {
            if (navigator.clipboard && navigator.clipboard.writeText) {
                await navigator.clipboard.writeText(str);
                return;
            }
        } catch (e) {
        }
        const el = document.createElement('textarea');
        el.value = str;
        el.setAttribute('readonly', '');
        el.style.position = 'fixed';
        el.style.left = '-9999px';
        document.body.appendChild(el);
        el.select();
        document.execCommand('copy');
        document.body.removeChild(el);
    }

    window.addEventListener('message', (event) => {
        const msg = event.data;
        if (!msg || !msg.type) return;

        if (msg.type === 'clipboard') {
            copyToClipboard(msg.data);
            return;
        } else if (msg.type === 'hover' || msg.type === 'mode') {
            return;
        }
    });
})();
