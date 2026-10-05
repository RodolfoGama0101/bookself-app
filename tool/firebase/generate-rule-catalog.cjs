// Atualiza somente validações de autores/catálogo local; não executa deploy.
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '../..');
const source = fs.readFileSync(path.join(root, 'lib/data/bible_data.dart'), 'utf8');
const books = [...source.matchAll(/BibleBook\(name: '([^']+)', chapters: (\d+)/g)]
  .map(([, name, chapters]) => ({name, chapters: Number(chapters)}));
if (books.length !== 66) throw Error('Catálogo bíblico inesperado');
const file = path.join(root, 'firestore.rules');
let rules = fs.readFileSync(file, 'utf8');
const authors = 'return authors is list && authors.size() <= 50\n' +
  Array.from({length: 50}, (_, i) => `        && (authors.size() <= ${i} || authors[${i}] is string)`).join('\n') + ';';
const catalog = 'return {\n' + books.map(({name, chapters}) =>
  `        '${name}': {'id': '${name.replaceAll(' ', '_').toLowerCase()}', 'chapters': ${chapters}}`).join(',\n') + '\n      };';
const counts = [...new Set(books.map(book => book.chapters))].sort((a, b) => a - b);
const ranges = 'return ' + counts.map(total =>
  `total == ${total} ? [${Array.from({length: total}, (_, i) => i+1).join(', ')}] :`).join('\n        ') + '\n        [];';
function replaceBody(name, body) {
  const expression = new RegExp(`(function ${name}\\([^)]*\\) \\{)[\\s\\S]*?(\\n    \\})`);
  if (!expression.test(rules)) throw Error(`Função ausente: ${name}`);
  rules = rules.replace(expression, `$1\n      ${body}$2`);
}
replaceBody('validAuthors', authors);
replaceBody('bibleBooks', catalog);
replaceBody('allowedChapters', ranges);
fs.writeFileSync(file, rules);
