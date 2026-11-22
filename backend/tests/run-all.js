// Runs every offline test (tests/*.test.js): `npm test`.
// The tests use a fake Firestore, a fake Konnect and a fake FCM:
// no Firebase key, no Internet and no real data are needed.
const { spawnSync } = require("child_process");
const fs = require("fs");
const path = require("path");

const files = fs
    .readdirSync(__dirname)
    .filter((file) => file.endsWith(".test.js"))
    .sort();

let failed = 0;

for (const file of files) {
    const result = spawnSync(process.execPath, [path.join(__dirname, file)], {
        encoding: "utf8",
        env: { ...process.env, KONNECT_MOCK: "true" }
    });

    const summary = (result.stdout.match(/ALL \d+ TESTS PASSED/) || [])[0];

    if (result.status === 0 && summary) {
        console.log(`✔ ${file.padEnd(24)} ${summary}`);
    } else {
        failed += 1;
        console.log(`✘ ${file}`);
        console.log(result.stdout.split("\n").filter((line) => /^ok|FAILED/.test(line)).join("\n"));
        console.log(result.stderr.split("\n").slice(-15).join("\n"));
    }
}

console.log(failed ? `\n${failed} test file(s) failed.` : `\nAll ${files.length} test files passed.`);
process.exit(failed ? 1 : 0);
