const { spawn } = require('child_process');

const command = 'sh';
const args = [
  '-c',
  `export PATH="$HOME/.nvm/versions/node/v24.11.0/bin:$PATH"; set -a; [ -f .env ] && . ./.env; set +a; npx -y mcp-remote https://stitch.googleapis.com/mcp --header "X-Goog-Api-Key: $STITCH_API_KEY"`
];

const child = spawn(command, args);

let buffer = '';
child.stdout.on('data', (data) => {
  buffer += data.toString();
  try {
    const lines = buffer.split('\n');
    for (let i = 0; i < lines.length - 1; i++) {
        const line = lines[i].trim();
        if (line && line.startsWith('{')) {
            const resp = JSON.parse(line);
            if (resp.result && resp.result.content) {
                const content = JSON.parse(resp.result.content[0].text);
                if (content.projects) {
                    content.projects.forEach(p => {
                        console.log(`PROJECT: ${p.displayName} (${p.name}) Created at: ${p.createTime}`);
                    });
                } else {
                    console.log('RESULT:', JSON.stringify(content));
                }
            }
        }
    }
    buffer = lines[lines.length - 1];
  } catch (e) {}
});

function send(method, params = {}) {
  const msg = {
    jsonrpc: '2.0',
    id: 1,
    method,
    params
  };
  child.stdin.write(JSON.stringify(msg) + '\n');
}

setTimeout(() => {
  send('tools/call', {
    name: 'list_projects',
    arguments: {}
  });
}, 5000);

setTimeout(() => {
    process.exit(0);
}, 10000);
