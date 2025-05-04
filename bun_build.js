import Bun from 'bun'

const args = process.argv.slice(2)

// console.log(args);


const result = await Bun.build({
    entrypoints: [args[0]],
    outdir: './output',
    target: 'browser',
})

if (!result.success) {
    console.error('Build failed')
    for (const message of result.logs) {
        // Bun will pretty print the message object
        console.error(message)
    }
}
