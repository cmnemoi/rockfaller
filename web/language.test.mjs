import assert from "node:assert/strict";
import test from "node:test";
import { chooseLanguage } from "./language.mjs";

test("the language in the address wins, so a shared link opens in that language", () => {
  assert.equal(chooseLanguage({ requested: "de", saved: "fr", browserLanguages: ["es"] }), "de");
});

test("without one in the address, the player's last choice wins", () => {
  assert.equal(chooseLanguage({ requested: null, saved: "fr", browserLanguages: ["es"] }), "fr");
});

test("on a first visit, the browser's first language the game knows is used", () => {
  assert.equal(chooseLanguage({ requested: null, saved: null, browserLanguages: ["ja", "pt-BR", "fr"] }), "pt");
});

test("languages the game does not know are skipped, and English is the last resort", () => {
  assert.equal(chooseLanguage({ requested: "xx", saved: "ja", browserLanguages: ["zh-CN"] }), "en");
});
