// Tile metadata needed by the Apple application's authoritative server.
const TILE_TYPES = [];
for (const [suit, prefix] of [['characters','m'], ['bamboo','s'], ['circle','p']]) {
  for (let rank = 1; rank <= 9; rank++) TILE_TYPES.push({id: `${prefix}${rank}`, category: 'suit', suit, rank});
}
for (const wind of ['E','S','W','N']) TILE_TYPES.push({id: `w${wind}`, category: 'wind'});
for (const dragon of ['R','G','W']) TILE_TYPES.push({id: `d${dragon}`, category: 'dragon'});
const TILE_TYPES_BY_ID = Object.fromEntries(TILE_TYPES.map(tile => [tile.id,tile]));
function shuffleArray(array) {
  for (let i = array.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [array[i], array[j]] = [array[j], array[i]];
  }
  return array;
}
