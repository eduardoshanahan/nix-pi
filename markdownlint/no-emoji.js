// Custom markdownlint rule to disallow emoji characters in Markdown.
// Loaded via markdownlint-cli2 config (see .markdownlint-cli2.yaml).
const buildEmojiRegex = () => {
  try {
    // Supported by modern Node versions.
    return /\p{Extended_Pictographic}/u;
  } catch {
    // Fallback: broad approximation (most emoji blocks + dingbats).
    return /[\u{1F000}-\u{1FAFF}\u2600-\u27BF]/u;
  }
};

const emojiRegex = buildEmojiRegex();

module.exports = {
  names: ["no-emojis"],
  description: "Disallow emoji characters",
  tags: ["style"],
  function: function noEmojis(params, onError) {
    for (let i = 0; i < params.lines.length; i++) {
      const line = params.lines[i];
      const match = emojiRegex.exec(line);
      if (match) {
        const index = match.index;
        const char = match[0];
        onError({
          lineNumber: i + 1,
          detail: `Emoji not allowed (found U+${char.codePointAt(0).toString(16).toUpperCase()}).`,
          range: [index + 1, char.length],
        });
      }
    }
  },
};

