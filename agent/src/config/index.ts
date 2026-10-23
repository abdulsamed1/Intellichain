import { Character, ModelProviderName, settings, validateCharacterConfig } from "@elizaos/core";
import fs from "fs";
import path from "path";

/*
 * Vendored from the elizaOS starter v0.1.1 (MIT) — src/config/index.ts,
 * adapted: the yargs dependency was dropped (two flags parsed via
 * process.argv); loadCharacters/getTokenForProvider kept as upstream.
 */

export interface ParsedArgs {
  character?: string;
  characters?: string;
}

export function parseArguments(): ParsedArgs {
  const argv = process.argv.slice(2);
  const pick = (name: string): string | undefined => {
    const flag = `--${name}`;
    const idx = argv.indexOf(flag);
    if (idx !== -1 && argv[idx + 1] !== undefined) {
      return argv[idx + 1];
    }
    const inline = argv.find((a) => a.startsWith(`${flag}=`));
    return inline?.slice(inline.indexOf("=") + 1);
  };

  const character = pick("character");
  const characters = pick("characters");
  return {
    ...(character !== undefined ? { character } : {}),
    ...(characters !== undefined ? { characters } : {}),
  };
}

export async function loadCharacters(
  charactersArg: string | undefined,
): Promise<Character[]> {
  const characterPaths = charactersArg
    ?.split(",")
    .map((filePath) => {
      if (path.basename(filePath) === filePath) {
        filePath = "../characters/" + filePath;
      }
      return path.resolve(process.cwd(), filePath.trim());
    });

  const loadedCharacters: Character[] = [];

  if (characterPaths !== undefined && characterPaths.length > 0) {
    for (const characterPath of characterPaths) {
      try {
        const character = JSON.parse(fs.readFileSync(characterPath, "utf8"));

        validateCharacterConfig(character);

        loadedCharacters.push(character);
      } catch (e) {
        console.error(`Error loading character from ${characterPath}: ${e}`);
        // don't continue to load if a specified file is not found
        process.exit(1);
      }
    }
  }

  return loadedCharacters;
}

export function getTokenForProvider(
  provider: ModelProviderName,
  character: Character,
) {
  switch (provider) {
    case ModelProviderName.OPENAI:
      return (
        character.settings?.secrets?.OPENAI_API_KEY || settings.OPENAI_API_KEY
      );
    case ModelProviderName.OPENROUTER:
      return (
        character.settings?.secrets?.OPENROUTER ||
        character.settings?.secrets?.OPENROUTER_API_KEY ||
        settings.OPENROUTER_API_KEY
      );
    default:
      return undefined;
  }
}
