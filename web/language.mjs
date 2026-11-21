// The languages the game ships, in the order of the flags on the page.
export const LANGUAGES = ["fr", "en", "es", "de", "it", "pt"];

const FALLBACK = "en";

/** The address wins, then the player's last choice, then the browser's languages. */
export function chooseLanguage({ requested, saved, browserLanguages }) {
  const candidates = [requested, saved, ...browserLanguages.map((tag) => tag.slice(0, 2).toLowerCase())];
  return candidates.find((language) => LANGUAGES.includes(language)) ?? FALLBACK;
}
