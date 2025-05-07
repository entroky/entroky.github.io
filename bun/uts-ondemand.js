const load_script = (src) => {
    console.debug(`loading ${src}`)
    const script = document.createElement('script')
    script.type = 'module'
    script.src = src
    document.head.appendChild(script)
}

const register = (selector, script) => {
    const tags = document.querySelectorAll(selector)

    if (tags.length !== 0) {
        load_script(script)
    }
}

document.addEventListener('DOMContentLoaded', async () => {
    // register('.link-reference', 'backref.js') // it works but not ideal
    register('.markdownit', 'markdownit.js')
    register('article code.highlight', 'shiki.js')
    register('.usegpu', 'usegpu.js')
<<<<<<< HEAD
    register('lite-youtube', 'lite-yt-embed.js');
=======
    register('lite-youtube', 'lite-yt-embed.js')
>>>>>>> a168bcb (youtube)
    const hostname = window.location.hostname

    if (hostname === 'localhost' || hostname === '127.0.0.1') {
        load_script('live.js')
    }
})
