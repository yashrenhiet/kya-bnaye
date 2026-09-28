# Image credits

Every recipe photo shipped in `assets/seed/images/` must have exactly one row in the table
below, and every row must match a recipe `imageAsset`. The seed asset test checks both.

## Policy

- v1 ships with every `imageAsset` set to `null`. The app renders a gradient and initial
  fallback card, so a missing photo never blocks a recipe.
- Licences: prefer CC0, public domain, Unsplash licence or Pexels licence. Avoid CC BY-SA,
  any NC (non-commercial) or ND (no-derivatives) licence.
- A human checks each licence before a photo is added. Agents do not source photos.
- Format: `images/<recipe id>.webp`, at most 60 KB (target about 40 KB).
- Record any crop, resize or colour change in the "modifications" column.

## Credits

| file | recipe id | title | author | source URL | licence | licence URL | retrieved | modifications |
|---|---|---|---|---|---|---|---|---|
