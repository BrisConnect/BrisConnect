const fs = require('fs');
const zlib = require('zlib');

const files = [
  'build/web/main.dart.js',
  'build/web/flutter_bootstrap.js',
];

for (const f of files) {
  if (!fs.existsSync(f)) continue;
  const data = fs.readFileSync(f);
  fs.writeFileSync(f + '.br', zlib.brotliCompressSync(data));
  fs.writeFileSync(f + '.gz', zlib.gzipSync(data));
  console.log(
    f,
    Math.round(data.length / 1024) + 'KB',
    'br',
    Math.round(fs.statSync(f + '.br').size / 1024) + 'KB',
    'gz',
    Math.round(fs.statSync(f + '.gz').size / 1024) + 'KB'
  );
}
