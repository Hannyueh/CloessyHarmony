/**
 * Cross-checks the fixed AES envelope constants against the Android reference
 * fixtures. Requires Node.js. This script never sees a real lock secret.
 */
const crypto = require('crypto');

const KEY = Buffer.from('94810265F7B0E3AC1A2DB50C0986374F', 'hex');
const IV = Buffer.from('4DB8100EC7635A9F7D20035AB864CFE1', 'hex');

function wrap(plainHex) {
  const cipher = crypto.createCipheriv('aes-128-cbc', KEY, IV);
  cipher.setAutoPadding(true);
  const encrypted = Buffer.concat([cipher.update(Buffer.from(plainHex, 'hex')), cipher.final()]);
  const total = encrypted.length + 3; // D2 D3 + length byte + ciphertext
  return 'd2d3' + total.toString(16).padStart(2, '0') + encrypted.toString('hex');
}

function unwrap(envelopeHex) {
  const envelope = Buffer.from(envelopeHex, 'hex');
  const decipher = crypto.createDecipheriv('aes-128-cbc', KEY, IV);
  decipher.setAutoPadding(true);
  return Buffer.concat([decipher.update(envelope.subarray(3)), decipher.final()]).toString('hex');
}

const cases = [
  ['d003a7', 'd2d313fb993af55838ca8c28ab15f75cd584a2'],
  ['d007a746464646', 'd2d31386b739e077d47c559eeaad5d54d28148'],
];

let ok = true;
for (const [plain, expected] of cases) {
  const actual = wrap(plain);
  const pass = actual === expected;
  ok = ok && pass;
  console.log(`${pass ? 'OK  ' : 'FAIL'} wrap(${plain}) = ${actual}`);
}

const keyError = unwrap('d2d313c1a8a527d31c418f6dad2b4adfa11ca6');
const keyErrorText = Buffer.from(keyError, 'hex').toString('ascii');
const keyPass = keyErrorText === 'SECRET_KEY_FAIL';
ok = ok && keyPass;
console.log(`${keyPass ? 'OK  ' : 'FAIL'} key-error payload = ${JSON.stringify(keyErrorText)}`);

process.exit(ok ? 0 : 1);
