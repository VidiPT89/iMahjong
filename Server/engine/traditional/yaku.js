/* Casual Riichi yaku and fu evaluation. Supported rules and omissions are in README.md. */

const GREEN_TILES = ['s2', 's3', 's4', 's6', 's8', 'dG'];

function isYakuhaiTile(typeId, seatWind, roundWind) {
  const t = TILE_TYPES_BY_ID[typeId];
  if (t.category === 'dragon') return true;
  if (t.category === 'wind') return typeId === seatWind || typeId === roundWind;
  return false;
}

function yakuhaiHanForTile(typeId, seatWind, roundWind) {
  const t = TILE_TYPES_BY_ID[typeId];
  let han = 0;
  if (t.category === 'dragon') han += 1;
  if (t.category === 'wind' && typeId === seatWind) han += 1;
  if (t.category === 'wind' && typeId === roundWind) han += 1;
  return han;
}

function winningGroup(decomp, ctx) { return decomp.groups[ctx.winningGroupIndex]; }
function isPinfu(decomp, ctx) {
  const group = winningGroup(decomp, ctx);
  return ctx.concealed && decomp.groups.every(g => g.kind === 'sequence')
    && !isYakuhaiTile(decomp.pair, ctx.seatWind, ctx.roundWind)
    && group && isRyanmenWait(group, ctx.winTile);
}

/** Ryanmen (two-sided) wait check for a sequence group containing winTile. */
function isRyanmenWait(group, winTile) {
  if (group.kind !== 'sequence') return false;
  const ranks = group.tiles.map((t) => RANK_OF[t]).sort((a, b) => a - b);
  const winRank = RANK_OF[winTile];
  const isEdge = (ranks[0] === 1 && winRank === 3) || (ranks[0] === 7 && winRank === 7);
  if (isEdge) return false;
  const isMiddle = winRank === ranks[1];
  return !isMiddle;
}

/**
 * Evaluates one decomposition of a winning hand and returns
 * { yakuList: [{name, han}], han, fu, yakuman, yakumanCount }.
 * Returns null (no yaku) if the hand has zero yaku — required to win.
 */
function evaluateDecomposition(decomp, ctx) {
  const { pair, groups } = decomp;
  const yakuList = [];
  let yakumanCount = 0;

  const allSimples = (ctx.handKind === 'chiitoitsu' || ctx.handKind === 'kokushi')
    ? ctx.concealedTiles
    : [pair, ...groups.flatMap((g) => g.tiles)];
  const suitsUsed = new Set(allSimples.filter((t) => TILE_TYPES_BY_ID[t].category === 'suit').map((t) => SUIT_OF[t]));
  const hasHonor = allSimples.some((t) => isHonor(t));
  const hasTerminal = allSimples.some((t) => isTerminal(t));
  const allTerminalOrHonor = allSimples.every((t) => isTerminalOrHonor(t));
  const allTriplets = groups.every((g) => g.kind === 'triplet');
  const concealedTripletCount = groups.filter((g, index) => g.kind === 'triplet' && (!g.meld || g.meld.concealed) && !(ctx.winType === 'ron' && ctx.winningGroupIndex === index)).length;

  // ---- Yakuman (checked first; if any apply, regular yaku are ignored) ----
  if (ctx.handKind === 'kokushi') {
    yakuList.push({ name: 'Kokushi Musou', han: 13 });
    yakumanCount += 1;
  }
  if (ctx.concealed && allTriplets && concealedTripletCount === 4) {
    yakuList.push({ name: 'Suuankou', han: 13 });
    yakumanCount += 1;
  }
  if (allTerminalOrHonor && hasHonor && !hasTerminal && suitsUsed.size === 0) {
    yakuList.push({ name: 'Tsuuiisou', han: 13 });
    yakumanCount += 1;
  }
  if (allTerminalOrHonor && !hasHonor) {
    yakuList.push({ name: 'Chinroutou', han: 13 });
    yakumanCount += 1;
  }
  if (allSimples.every((t) => GREEN_TILES.includes(t))) {
    yakuList.push({ name: 'Ryuuiisou', han: 13 });
    yakumanCount += 1;
  }
  {
    const dragonTriplets = groups.filter((g) => g.kind === 'triplet' && TILE_TYPES_BY_ID[g.tiles[0]].category === 'dragon');
    if (dragonTriplets.length === 3) { yakuList.push({ name: 'Daisangen', han: 13 }); yakumanCount += 1; }
  }
  if (ctx.openMelds && ctx.openMelds.filter((m) => m.kind === 'kan').length >= 4) {
    yakuList.push({ name: 'Suukantsu', han: 13 });
    yakumanCount += 1;
  }

  if (yakumanCount > 0) {
    const han = yakuList.reduce((s, y) => s + y.han, 0);
    return { yakuList, han, fu: 20, yakuman: true, yakumanCount };
  }

  // ---- Regular yaku ----
  if (ctx.handKind === 'chiitoitsu') {
    yakuList.push({ name: 'Chiitoitsu', han: 2 });
  }

  if (ctx.doubleRiichi) yakuList.push({ name: 'Double Riichi', han: 2 });
  else if (ctx.riichi) yakuList.push({ name: 'Riichi', han: 1 });
  if (ctx.riichi && ctx.ippatsu) yakuList.push({ name: 'Ippatsu', han: 1 });
  if (ctx.concealed && ctx.winType === 'tsumo') yakuList.push({ name: 'Menzen Tsumo', han: 1 });
  if (ctx.haitei) yakuList.push({ name: 'Haitei Raoyue', han: 1 });
  if (ctx.houtei) yakuList.push({ name: 'Houtei Raoyui', han: 1 });
  if (ctx.rinshan) yakuList.push({ name: 'Rinshan Kaihou', han: 1 });
  if (ctx.chankan) yakuList.push({ name: 'Chankan', han: 1 });

  if (!hasHonor && !hasTerminal) yakuList.push({ name: 'Tanyao', han: 1 });
  if (allTerminalOrHonor) yakuList.push({ name: 'Honroutou', han: 2 });

  if (ctx.handKind === 'standard') {

    groups.forEach((g) => {
      if (g.kind === 'triplet') {
        const han = yakuhaiHanForTile(g.tiles[0], ctx.seatWind, ctx.roundWind);
        if (han > 0) yakuList.push({ name: `Yakuhai (${TILE_TYPES_BY_ID[g.tiles[0]].id})`, han });
      }
    });

    if (isPinfu(decomp, ctx)) yakuList.push({name: 'Pinfu', han: 1});
    const sequences = groups.filter(g => g.kind === 'sequence');
    const counts = {};
    sequences.forEach(g => { const key = g.tiles.join(','); counts[key] = (counts[key] || 0) + 1; });
    if (ctx.concealed) {
      const pairs = Object.values(counts).reduce((total, count) => total + Math.floor(count / 2), 0);
      if (pairs >= 2) yakuList.push({name: 'Ryanpeikou', han: 3});
      else if (pairs === 1) yakuList.push({name: 'Iipeiko', han: 1});
    }
    const suits = ['characters', 'bamboo', 'circle'];
    if ([1,2,3,4,5,6,7].some(rank => suits.every(suit => sequences.some(g => SUIT_OF[g.tiles[0]] === suit && RANK_OF[g.tiles[0]] === rank)))) {
      yakuList.push({name: 'Sanshoku Doujun', han: ctx.concealed ? 2 : 1});
    }
    suits.forEach(suit => {
      const ranks = sequences.filter(g => SUIT_OF[g.tiles[0]] === suit).map(g => RANK_OF[g.tiles[0]]);
      if ([1,4,7].every(rank => ranks.includes(rank))) yakuList.push({name: 'Ittsu', han: ctx.concealed ? 2 : 1});
    });
    if ([1,2,3,4,5,6,7,8,9].some(rank => suits.every(suit => groups.some(g => g.kind === 'triplet' && SUIT_OF[g.tiles[0]] === suit && RANK_OF[g.tiles[0]] === rank)))) {
      yakuList.push({name: 'Sanshoku Doukou', han: 2});
    }
    if (ctx.openMelds.filter(m => m.kind === 'kan').length === 3) yakuList.push({name: 'Sankantsu', han: 2});
    if (allTriplets) yakuList.push({name: 'Toitoi', han: 2});
    if (concealedTripletCount === 3) yakuList.push({ name: 'Sanankou', han: 2 });

    const chantaShape = [pair, ...groups.map((g) => g.tiles)].every((grp) => {
      const arr = Array.isArray(grp) ? grp : [grp];
      return arr.some((t) => isTerminalOrHonor(t));
    });
    if (chantaShape && sequences.length > 0) {
      if (!hasHonor) yakuList.push({ name: 'Junchan', han: ctx.concealed ? 3 : 2 });
      else yakuList.push({ name: 'Chanta', han: ctx.concealed ? 2 : 1 });
    }
  }

  if (hasHonor && suitsUsed.size === 1) yakuList.push({ name: 'Honitsu', han: ctx.concealed ? 3 : 2 });
  else if (!hasHonor && suitsUsed.size === 1) yakuList.push({ name: 'Chinitsu', han: ctx.concealed ? 6 : 5 });

  {
    const dragonTriplets = groups.filter((g) => g.kind === 'triplet' && TILE_TYPES_BY_ID[g.tiles[0]].category === 'dragon').length;
    const dragonPair = TILE_TYPES_BY_ID[pair] && TILE_TYPES_BY_ID[pair].category === 'dragon';
    if (dragonTriplets === 2 && dragonPair) yakuList.push({ name: 'Shousangen', han: 2 });
  }

  if (yakuList.length === 0) return null;

  const han = yakuList.reduce((s, y) => s + y.han, 0) + (ctx.doraCount || 0) + (ctx.uraDoraCount || 0);
  const fu = calculateFu(decomp, ctx);
  return { yakuList, han, fu, yakuman: false, yakumanCount: 0 };
}

function calculateFu(decomp, ctx) {
  if (ctx.handKind === 'chiitoitsu') return 25;

  const { pair, groups } = decomp;
  if (isPinfu(decomp, ctx)) return ctx.winType === 'ron' ? 30 : 20;

  let fu = 20;
  if (ctx.concealed && ctx.winType === 'ron') fu += 10;
  if (ctx.winType === 'tsumo') fu += 2;

  groups.forEach((g, index) => {
    if (g.kind !== 'triplet') return;
    const termHonor = isTerminalOrHonor(g.tiles[0]);
    const concealedGroup = (!g.meld || g.meld.concealed) && !(ctx.winType === 'ron' && ctx.winningGroupIndex === index);
    if (g.meld && g.meld.kind === 'kan') fu += termHonor ? (concealedGroup ? 32 : 16) : (concealedGroup ? 16 : 8);
    else fu += termHonor ? (concealedGroup ? 8 : 4) : (concealedGroup ? 4 : 2);
  });

  if (isYakuhaiTile(pair, ctx.seatWind, ctx.roundWind)) {
    fu += 2 * yakuhaiHanForTile(pair, ctx.seatWind, ctx.roundWind);
  }

  const group = winningGroup(decomp, ctx);
  if (ctx.winningGroupIndex === -1) fu += 2;
  else if (group && group.kind === 'sequence' && !isRyanmenWait(group, ctx.winTile)) fu += 2;
  return Math.max(30, Math.ceil(fu / 10) * 10);
}

/** Tries every decomposition and returns the highest-scoring valid result. */
function bestYakuResult(winCheck, concealedTiles, ctx) {
  let best = null;
  if (winCheck.kind === 'chiitoitsu' || winCheck.kind === 'kokushi') {
    best = evaluateDecomposition({ pair: null, groups: [] }, { ...ctx, handKind: winCheck.kind, concealedTiles });
  }
  winCheck.decompositions.forEach((decomp) => {
    const indices = decomp.groups.map((_, i) => i).filter(i => !decomp.groups[i].meld && decomp.groups[i].tiles.includes(ctx.winTile));
    if (decomp.pair === ctx.winTile) indices.push(-1);
    indices.forEach(winningGroupIndex => {
      const result = evaluateDecomposition(decomp, {...ctx, handKind: 'standard', winningGroupIndex});
      if (result && (!best || compareResults(result, best) > 0)) best = result;
    });
  });
  return best;
}

function compareResults(a, b) {
  if (a.yakuman !== b.yakuman) return a.yakuman ? 1 : -1;
  if (a.yakuman) return a.yakumanCount - b.yakumanCount;
  const scoreDifference = baseScoreFromHanFu(a.han, a.fu, false, 0) - baseScoreFromHanFu(b.han, b.fu, false, 0);
  if (scoreDifference) return scoreDifference;
  if (a.han !== b.han) return a.han - b.han;
  return a.fu - b.fu;
}
