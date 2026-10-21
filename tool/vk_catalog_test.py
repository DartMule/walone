"""Проверки пагинации и лимита собственного скрипта каталога VK без сети."""
import json
from pathlib import Path
import shutil
import subprocess
import unittest


@unittest.skipUnless(shutil.which('node'), 'Нужен Node.js для выполнения JS')
class VkCatalogTest(unittest.TestCase):
    def run_catalog(self, limit):
        source = (Path(__file__).parent / 'resource_sources/import/catalogScript.js').read_text()
        script = r'''
const assert = require('node:assert/strict');
const run = new (Object.getPrototypeOf(async function(){}).constructor)(
  'targetOwnerID', 'targetID', 'accessKey', 'isPlaylist', 'trackLimit', SOURCE);
global.window = {vk: {id: 123}};
global.location = {hostname: 'm.vk.ru'};
global.document = {cookie: '', title: 'VK', querySelector: () => null,
  createElement: () => ({set innerHTML(s) {this.value = s;}})};
global.setTimeout = (fn, delay) => delay < 20000 ? (fn(), 0) : 0;
global.clearTimeout = () => {};
const offsets = [];
global.fetch = async (url, {body}) => {
  assert.equal(body.get('type'), 'playlist');
  assert.equal(body.get('playlist_id'), '-1');
  assert.equal(body.get('owner_id'), '123');
  offsets.push(Number(body.get('offset')));
  const first = offsets.length === 1;
  return {ok: true, text: async () => JSON.stringify({data: [{
    list: first ? [[1,123,'','Первый','Автор',10], [2,123,'','Второй','Автор',11]] : [[3,123,'','Третий','Автор',12]],
    hasMore: first, nextOffset: 2000,
  }]})};
};
run('', 'all', '', true, LIMIT).then(result => console.log(JSON.stringify({result, offsets})));
'''.replace('SOURCE', json.dumps(source)).replace('LIMIT', str(limit))
        result = subprocess.run(['node', '-e', script], text=True, capture_output=True, check=True)
        return json.loads(result.stdout)

    def test_limit_stops_before_second_page(self):
        data = self.run_catalog(1)
        self.assertEqual(len(data['result']['tracks']), 1)
        self.assertEqual(data['offsets'], [0])
        self.assertEqual(data['result']['name'], 'Моя музыка VK')

    def test_unlimited_uses_server_offset(self):
        data = self.run_catalog(0)
        self.assertEqual(len(data['result']['tracks']), 3)
        self.assertEqual(data['offsets'], [0, 2000])


if __name__ == '__main__':
    unittest.main()
