/* Traditional 4-player Riichi turn engine — pure state machine, no UI or
   network code. One instance plays exactly one hand (deal to win/draw);
   a thin "match" wrapper (see match.js) chains hands together with dealer
   rotation and point totals.

   Deliberate scope simplifications (documented, not accidental gaps):
   - No abortive draws (four-riichi, four-kan, nine-terminals, four-wind).
   - Multi-ron pays each winner in full from the discarder (no atama-hane).
   - Added kans/chankan are not offered; at most four open/concealed kans.
*/

function isTenpaiWithMelds(concealedTiles, melds) {
  for (const type of STANDARD_TYPE_IDS) {
    const wc = checkWin([...concealedTiles, type], melds);
    if (wc.win) return true;
  }
  return false;
}

function chiOptionsFor(hand, tile) {
  const rank = RANK_OF[tile];
  if (rank === null) return [];
  const suitPrefix = tile[0];
  const has = (r) => hand.includes(`${suitPrefix}${r}`);
  const options = [];
  if (rank >= 3 && has(rank - 2) && has(rank - 1)) options.push([`${suitPrefix}${rank - 2}`, `${suitPrefix}${rank - 1}`]);
  if (rank >= 2 && rank <= 8 && has(rank - 1) && has(rank + 1)) options.push([`${suitPrefix}${rank - 1}`, `${suitPrefix}${rank + 1}`]);
  if (rank <= 7 && has(rank + 1) && has(rank + 2)) options.push([`${suitPrefix}${rank + 1}`, `${suitPrefix}${rank + 2}`]);
  return options;
}

function countInHand(hand, type) {
  return hand.filter((t) => t === type).length;
}

class RiichiEngine {
  constructor({ dealerSeat = 0, roundWind = 'wE', seatWinds, isBot = [false, true, true, true], points }) {
    const { liveWall, deadWall, hands } = dealWall();
    this.liveWall = liveWall;
    this.deadWall = deadWall;
    this.dealerSeat = dealerSeat;
    this.roundWind = roundWind;
    this.doraRevealedCount = 1;
    this.uraDoraRevealedCount = 1;
    this.kanCount = 0;
    this.replacementDrawCount = 0;
    this.anyCall = false;

    const winds = seatWinds || ['wE', 'wS', 'wW', 'wN'].map((_, i) => ['wE', 'wS', 'wW', 'wN'][(i - dealerSeat + 4) % 4]);
    this.seats = [0, 1, 2, 3].map((i) => ({
      seatIndex: i,
      wind: winds[i],
      isBot: isBot[i],
      hand: hands[i].map((t) => t.typeId).sort(),
      melds: [],
      discards: [],
      discardHistory: [],
      riichi: false,
      doubleRiichi: false,
      ippatsuActive: false,
      furitenUntilNextDraw: false,
      points: points ? points[i] : 25000,
    }));

    this.currentSeat = dealerSeat;
    this.phase = 'draw';
    this.lastDiscard = null;
    this.turnDrawnTile = null;
    this.isRinshanDraw = false;
    this.result = null;

  }

  seat(i) { return this.seats[i]; }
  activeSeat() { return this.seats[this.currentSeat]; }

  doraIndicators() { return this.deadWall.slice(0, this.doraRevealedCount).map((t) => t.typeId); }
  uraDoraIndicators() { return this.deadWall.slice(5, 5 + this.uraDoraRevealedCount).map((t) => t.typeId); }

  doraTypeFor(indicator) {
    const t = TILE_TYPES_BY_ID[indicator];
    if (t.category === 'suit') {
      const nextRank = t.rank === 9 ? 1 : t.rank + 1;
      return `${indicator[0]}${nextRank}`;
    }
    if (t.category === 'wind') {
      const order = ['wE', 'wS', 'wW', 'wN'];
      return order[(order.indexOf(indicator) + 1) % 4];
    }
    const order = ['dR', 'dG', 'dW'];
    return order[(order.indexOf(indicator) + 1) % 3];
  }

  countDora(concealedTiles, melds, indicators) {
    const doraTypes = indicators.map((ind) => this.doraTypeFor(ind));
    const allTiles = [...concealedTiles, ...melds.flatMap((m) => m.tiles)];
    return doraTypes.reduce((total, type) => total + allTiles.filter(t => t === type).length, 0);
  }

  /** Draws the next tile for the active seat (from live wall, or dead wall after a kan). */
  draw() {
    const fromDead = this.isRinshanDraw;

    if (!fromDead && this.liveWall.length === 0) {
      this.result = this.buildExhaustiveDraw();
      this.phase = 'ended';
      return { type: 'exhaustive', result: this.result };
    }
    let tile;
    if (fromDead) {
      const index = 13 - this.replacementDrawCount++;
      tile = this.deadWall[index];
      this.deadWall[index] = this.liveWall.pop();
    } else tile = this.liveWall.pop();

    const seat = this.activeSeat();
    if (!seat.riichi) seat.furitenUntilNextDraw = false;
    seat.hand.push(tile.typeId);
    seat.hand.sort();
    this.turnDrawnTile = tile.typeId;
    this.phase = 'discard';
    return { type: 'drawn', seat: this.currentSeat, tile: tile.typeId, rinshan: fromDead };
  }

  canDeclareTsumo() {
    // Tsumo (and kan, see canAnkan) require a self-draw — right after calling
    // pon/chi on someone else's discard you owe an immediate discard, not a win.
    if (this.phase !== 'discard' || this.turnDrawnTile === null) return false;
    const seat = this.activeSeat();
    const wc = checkWin(seat.hand, seat.melds);
    if (!wc.win) return false;
    const result = this.evaluateWin(seat, wc, this.turnDrawnTile, 'tsumo');
    return result !== null;
  }

  declareTsumo() {
    // Authoritative guard: a client (bot, human, or a malicious/buggy
    // network peer) could call this on a non-winning hand. checkWin()
    // returns {win:false} with no `decompositions`, which bestYakuResult()
    // would crash on — so re-validate here rather than trusting the caller.
    if (!this.canDeclareTsumo()) return null;
    const seat = this.activeSeat();
    const wc = checkWin(seat.hand, seat.melds);
    const result = this.evaluateWin(seat, wc, this.turnDrawnTile, 'tsumo');
    this.result = { type: 'tsumo', seat: this.currentSeat, ...result };
    this.phase = 'ended';
    return this.result;
  }

  evaluateWin(seat, winCheck, winTile, winType) {
    const concealed = winType === 'ron' ? [...seat.hand, winTile] : seat.hand;
    const ctx = {
      concealed: seat.melds.every((m) => m.concealed),
      openMelds: seat.melds,
      winTile,
      winType,
      seatWind: seat.wind,
      roundWind: this.roundWind,
      riichi: seat.riichi,
      doubleRiichi: seat.doubleRiichi,
      ippatsu: seat.ippatsuActive,
      haitei: winType === 'tsumo' && this.liveWall.length === 0 && !this.isRinshanDraw,
      houtei: winType === 'ron' && this.liveWall.length === 0,
      rinshan: winType === 'tsumo' && this.isRinshanDraw,
      chankan: false,
      doraCount: this.countDora(concealed, seat.melds, this.doraIndicators()),
      uraDoraCount: seat.riichi ? this.countDora(concealed, seat.melds, this.uraDoraIndicators()) : 0,
    };
    const best = bestYakuResult(winCheck, concealed, ctx);
    if (!best) return null;
    const score = scorePoints(best, { isDealer: seat.seatIndex === this.dealerSeat, winType });
    return { ...best, ...score, concealedAtWin: concealed };
  }

  /** Checks ron eligibility for `seat` against the current lastDiscard, respecting furiten. */
  canRon(seatIndex) {
    const seat = this.seats[seatIndex];
    if (!seat || this.phase !== 'reaction' || !this.lastDiscard || this.lastDiscard.seat === seatIndex) return false;
    const tile = this.lastDiscard.tile;
    if (seat.discardHistory.some(tile => checkWin([...seat.hand, tile], seat.melds).win)) return false;
    if (seat.furitenUntilNextDraw) return false;
    const wc = checkWin([...seat.hand, tile], seat.melds);
    if (!wc.win) return false;
    return this.evaluateWin(seat, wc, tile, 'ron') !== null;
  }

  discard(tile) {
    const seat = this.activeSeat();
    const idx = seat.hand.indexOf(tile);
    if (idx === -1 || !this.legalDiscards().includes(tile)) return {};
    seat.hand.splice(idx, 1);
    seat.discards.push({ tile, calledAway: false });
    seat.discardHistory.push(tile);
    this.lastDiscard = { seat: this.currentSeat, tile };
    this.isRinshanDraw = false;
    this.turnDrawnTile = null;

    // Ippatsu survives only through one uninterrupted go-around with no calls.
    if (seat.riichi) seat.ippatsuActive = seat.justDeclaredRiichi ? true : false;
    seat.justDeclaredRiichi = false;

    // Anyone who could have ron'd but the discard passes untouched becomes
    // furiten-until-next-draw only if we actually offer & they decline —
    // handled by the caller via markPassedRon(). Here we just open reactions.
    this.phase = 'reaction';
    return this.getReactionSummary();
  }

  getReactionSummary() {
    const summary = {};
    if (!this.lastDiscard) return summary;
    for (let i = 0; i < 4; i++) {
      if (i === this.lastDiscard.seat) continue;
      const seat = this.seats[i];
      const opts = { ron: this.canRon(i), pon: false, kan: false, chi: [] };
      // Once riichi is declared the hand is locked — no more calls, only ron.
      if (!seat.riichi && this.liveWall.length > 0) {
        const cnt = countInHand(seat.hand, this.lastDiscard.tile);
        opts.pon = cnt >= 2;
        opts.kan = cnt >= 3 && this.kanCount < 4;
        if (i === (this.lastDiscard.seat + 1) % 4) opts.chi = chiOptionsFor(seat.hand, this.lastDiscard.tile);
      }
      summary[i] = opts;
    }
    return summary;
  }

  /** Marks a seat as having declined an available ron (temporary furiten). */
  markPassedRon(seatIndex) {
    this.seats[seatIndex].furitenUntilNextDraw = true;
  }

  /**
   * Resolves one discard's reaction window given each seat's declared
   * intent: responses = { [seatIndex]: 'ron'|'pon'|'kan'|{chi:[t1,t2]}|'pass' }.
   * Applies standard priority: ron > pon/kan > chi > nothing.
   */
  resolveReactions(responses) {
    // Re-validate every claimed action against freshly-computed legality —
    // never trust `responses` at face value (it may come straight from an
    // untrusted network client in online play).
    const summary = this.getReactionSummary();

    const ronSeats = Object.keys(responses).map(Number).filter((i) => responses[i] === 'ron' && this.canRon(i));
    if (ronSeats.length > 0) {
      const winners = ronSeats.map((i) => {
        const seat = this.seats[i];
        const wc = checkWin([...seat.hand, this.lastDiscard.tile], seat.melds);
        const result = this.evaluateWin(seat, wc, this.lastDiscard.tile, 'ron');
        return { seat: i, ...result };
      });
      this.result = { type: 'ron', discarder: this.lastDiscard.seat, winners };
      this.phase = 'ended';
      return this.result;
    }

    Object.keys(responses).forEach((i) => {
      if (responses[i] !== 'ron' && summary[i]?.ron) this.seats[Number(i)].furitenUntilNextDraw = true;
    });

    const ponSeat = Object.keys(responses).map(Number).find((i) => (
      (responses[i] === 'pon' && summary[i] && summary[i].pon)
      || (responses[i] === 'kan' && summary[i] && summary[i].kan)
    ));
    if (ponSeat !== undefined) {
      this.breakAllIppatsu();
      if (responses[ponSeat] === 'kan') return this.callDaiminkan(ponSeat);
      return this.callPon(ponSeat);
    }

    const chiSeat = Object.keys(responses).map(Number).find((i) => (
      responses[i] && responses[i].chi && summary[i] && summary[i].chi.some(
        (pair) => pair[0] === responses[i].chi[0] && pair[1] === responses[i].chi[1],
      )
    ));
    if (chiSeat !== undefined) {
      this.breakAllIppatsu();
      return this.callChi(chiSeat, responses[chiSeat].chi);
    }

    this.currentSeat = (this.lastDiscard.seat + 1) % 4;
    this.phase = 'draw';
    return { type: 'advance', nextSeat: this.currentSeat };
  }

  breakAllIppatsu() {
    this.anyCall = true;
    this.seats.forEach((s) => { s.ippatsuActive = false; });
  }

  /** Physically removes the just-made discard from the pile — it moves into a meld, so it must
   *  stop being counted as a discard (it stays visible via meld.calledFrom for UI purposes). */
  takeLastDiscardIntoMeld() {
    const discarder = this.seats[this.lastDiscard.seat];
    return discarder.discards.pop();
  }

  callChi(seatIndex, usingTiles) {
    const seat = this.seats[seatIndex];
    const tile = this.lastDiscard.tile;
    usingTiles.forEach((t) => {
      const idx = seat.hand.indexOf(t);
      seat.hand.splice(idx, 1);
    });
    seat.melds.push({ kind: 'chi', tiles: [...usingTiles, tile].sort(), concealed: false, calledFrom: this.lastDiscard.seat });
    this.takeLastDiscardIntoMeld();
    this.currentSeat = seatIndex;
    this.phase = 'discard';
    this.isRinshanDraw = false;
    return { type: 'called', kind: 'chi', seat: seatIndex };
  }

  callPon(seatIndex) {
    const seat = this.seats[seatIndex];
    const tile = this.lastDiscard.tile;
    for (let n = 0; n < 2; n++) seat.hand.splice(seat.hand.indexOf(tile), 1);
    seat.melds.push({ kind: 'pon', tiles: [tile, tile, tile], concealed: false, calledFrom: this.lastDiscard.seat });
    this.takeLastDiscardIntoMeld();
    this.currentSeat = seatIndex;
    this.phase = 'discard';
    this.isRinshanDraw = false;
    return { type: 'called', kind: 'pon', seat: seatIndex };
  }

  callDaiminkan(seatIndex) {
    if (this.kanCount >= 4) return this.callPon(seatIndex); // 5th kan disallowed — degrade to pon-less no-op guard
    const seat = this.seats[seatIndex];
    const tile = this.lastDiscard.tile;
    for (let n = 0; n < 3; n++) seat.hand.splice(seat.hand.indexOf(tile), 1);
    seat.melds.push({ kind: 'kan', tiles: [tile, tile, tile, tile], concealed: false, calledFrom: this.lastDiscard.seat });
    this.takeLastDiscardIntoMeld();
    this.kanCount++;
    this.doraRevealedCount++;
    this.uraDoraRevealedCount++;
    this.currentSeat = seatIndex;
    this.isRinshanDraw = true;
    this.phase = 'draw';
    return { type: 'called', kind: 'daiminkan', seat: seatIndex };
  }

  canAnkan(seatIndex) {
    // Ankan requires a self-draw, same as tsumo — see canDeclareTsumo().
    if (this.phase !== 'discard' || seatIndex !== this.currentSeat || this.turnDrawnTile === null || this.kanCount >= 4 || this.liveWall.length === 0) return [];
    const seat = this.seats[seatIndex];
    // Simplification: ankan after riichi is disallowed outright here (real
    // rules allow it only when it can't change the wait — narrow edge case).
    if (seat.riichi) return [];
    return STANDARD_TYPE_IDS.filter((t) => countInHand(seat.hand, t) === 4);
  }

  callAnkan(seatIndex, type) {
    if (this.kanCount >= 4) return null;
    if (!this.canAnkan(seatIndex).includes(type)) return null;
    this.breakAllIppatsu();
    const seat = this.seats[seatIndex];
    for (let n = 0; n < 4; n++) seat.hand.splice(seat.hand.indexOf(type), 1);
    seat.melds.push({ kind: 'kan', tiles: [type, type, type, type], concealed: true, calledFrom: null });
    this.kanCount++;
    this.doraRevealedCount++;
    this.uraDoraRevealedCount++;
    this.isRinshanDraw = true;
    this.phase = 'draw';
    return { type: 'called', kind: 'ankan', seat: seatIndex };
  }

  isTenpai(seatIndex) {
    const seat = this.seats[seatIndex];
    return isTenpaiWithMelds(seat.hand, seat.melds);
  }

  riichiDiscards(seatIndex) {
    if (this.phase !== 'discard' || seatIndex !== this.currentSeat || this.turnDrawnTile === null) return [];
    const seat = this.seats[seatIndex];
    if (!seat.melds.every(m => m.concealed) || this.liveWall.length < 4 || (seat.points < 1000 && !seat.justDeclaredRiichi)) return [];
    return [...new Set(seat.hand)].sort().filter(tile => {
      const hand = [...seat.hand];
      hand.splice(hand.indexOf(tile), 1);
      return isTenpaiWithMelds(hand, seat.melds);
    });
  }

  legalDiscards() {
    if (this.phase !== 'discard') return [];
    const seat = this.activeSeat();
    if (seat.justDeclaredRiichi) return this.riichiDiscards(this.currentSeat);
    if (seat.riichi) return this.turnDrawnTile ? [this.turnDrawnTile] : [];
    return [...new Set(seat.hand)].sort();
  }

  canDeclareRiichi(seatIndex) {
    return !this.seats[seatIndex].riichi && this.riichiDiscards(seatIndex).length > 0;
  }

  declareRiichi(seatIndex) {
    if (!this.canDeclareRiichi(seatIndex)) return false;
    const seat = this.seats[seatIndex];
    seat.riichi = true;
    seat.doubleRiichi = seat.discardHistory.length === 0 && !this.anyCall;
    seat.justDeclaredRiichi = true;
    seat.points -= 1000;
    return true;
  }

  buildExhaustiveDraw() {
    const tenpaiSeats = [0, 1, 2, 3].filter((i) => this.isTenpai(i));
    const notenSeats = [0, 1, 2, 3].filter((i) => !tenpaiSeats.includes(i));
    const payments = {};
    if (tenpaiSeats.length > 0 && tenpaiSeats.length < 4) {
      const totalPot = 3000;
      const perNoten = Math.floor(totalPot / notenSeats.length / 100) * 100;
      const perTenpai = Math.floor(totalPot / tenpaiSeats.length / 100) * 100;
      notenSeats.forEach((i) => { payments[i] = -perNoten; });
      tenpaiSeats.forEach((i) => { payments[i] = perTenpai; });
    } else {
      [0, 1, 2, 3].forEach((i) => { payments[i] = 0; });
    }
    return { type: 'exhaustive', tenpaiSeats, notenSeats, payments, dealerTenpai: tenpaiSeats.includes(this.dealerSeat) };
  }
}
