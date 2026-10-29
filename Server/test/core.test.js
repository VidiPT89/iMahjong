const {test} = require('node:test');
const assert = require('node:assert/strict');
const {RiichiEngine, LocalMatch, chooseBotReaction, chooseBotAnkan} = require('../shared-engine');
const {Room} = require('../room');
const waiting = ['m1','m2','m3','p1','p2','p3','s1','s2','s3','wE','wE','wE','dR'];

test('riichi preserves tenpai and rejects illegal discards', () => {
  const g = new RiichiEngine({});
  g.seats[0].hand = [...waiting, 'p9'];
  g.turnDrawnTile = 'p9'; g.phase = 'discard';
  assert.equal(g.declareRiichi(0), true);
  assert.deepEqual(Array.from(g.legalDiscards()), ['dR', 'p9']);
  g.discard('m1');
  assert.equal(g.phase, 'discard');
  g.discard('p9');
  g.resolveReactions({});
  assert.equal(g.seats[0].ippatsuActive, true);
});

test('duplicate indicators each award dora', () => {
  assert.equal(new RiichiEngine({}).countDora(['m2','m2'], [], ['m1','m1']), 4);
});

test('malformed discard cannot crash a room or change the hand', () => {
  const room = new Room('ABCDE', {LocalMatch});
  const socket = {readyState: 1, send() {}};
  room.addPlayer(socket, 'test-player', 'Player');
  room.start();
  try {
    const hand = [...room.match.engine.seats[0].hand];
    room.handleMessage(socket, {type: 'discard', tile: null});
    assert.deepEqual([...room.match.engine.seats[0].hand], hand);
    assert.ok(room.buildStateFor(0).legalDiscards.length > 0);
    assert.equal(room.buildStateFor(1).legalDiscards.length, 0);
  } finally { room.destroy(); }
});

test('settling a winning hand pays this hands deposits once', () => {
  const match = new LocalMatch({isHuman: [true,true,true,true], onChange() {}});
  try {
    match.startHand();
    const g = match.engine;
    g.seats[0].hand = [...waiting, 'dR'];
    g.turnDrawnTile = 'dR'; g.phase = 'discard';
    g.seats[0].riichi = true; g.seats[0].points = 24000;
    match.humanDeclareTsumo();
    assert.equal(match.points.reduce((a,b) => a+b, 0), 100000);
    const points = [...match.points];
    match.finishHand();
    assert.deepEqual([...match.points], points);
    assert.equal(match.riichiSticksOnTable, 0);
  } finally { match.stop(); }
});

test('twenty complete hands conserve all 136 tiles through draws and calls', () => {
  for (let run = 0; run < 20; run++) {
    const g = new RiichiEngine({});
    let turns = 0;
    while (g.phase !== 'ended' && turns++ < 500) {
      if (g.phase === 'draw') g.draw();
      else if (g.phase === 'discard') {
        if (g.canDeclareTsumo()) g.declareTsumo();
        else {
          const kan = chooseBotAnkan(g, g.currentSeat);
          if (kan) g.callAnkan(g.currentSeat, kan);
          else {
            if (g.canDeclareRiichi(g.currentSeat)) g.declareRiichi(g.currentSeat);
            g.discard(g.legalDiscards()[0]);
          }
        }
      } else {
        const responses = {};
        for (const [seat, options] of Object.entries(g.getReactionSummary())) {
          responses[seat] = chooseBotReaction(g, Number(seat), options);
        }
        g.resolveReactions(responses);
      }
      const count = g.liveWall.length + g.deadWall.length + g.seats.reduce((n,s) => n+s.hand.length+s.discards.length+s.melds.reduce((v,m) => v+m.tiles.length,0),0);
      assert.equal(count,136);
    }
    assert.equal(g.phase,'ended');
  }
});

test('seven pairs can combine with tanyao and menzen tsumo', () => {
  const g = new RiichiEngine({});
  g.seats[0].hand = ['m2','m2','m4','m4','p3','p3','p5','p5','s2','s2','s6','s6','s8','s8'];
  g.turnDrawnTile = 's8'; g.phase = 'discard';
  const result = g.declareTsumo();
  assert.ok(result);
  assert.equal(result.fu,25);
  assert.deepEqual(Array.from(result.yakuList.map(y => y.name)).sort(), ['Chiitoitsu','Menzen Tsumo','Tanyao']);
});

test('missing orphan is not a thirteen-orphans win', () => {
  const g = new RiichiEngine({});
  g.seats[0].hand = ['m1','m1','m1','m9','p1','p9','s1','s9','wE','wS','wW','wN','dR','dG'];
  g.turnDrawnTile = 'm1'; g.phase = 'discard';
  assert.equal(g.canDeclareTsumo(),false);
});

test('winning seven of 789 is an edge wait and does not award pinfu', () => {
  const g = new RiichiEngine({});
  g.seats[0].hand = ['m7','m8','m9','p1','p2','p3','s1','s2','s3','s4','s5','s6','p5','p5'];
  g.turnDrawnTile = 'm7'; g.phase = 'discard';
  const result = g.declareTsumo();
  assert.equal(result.fu,30);
  assert.equal(result.yakuList.some(y => y.name === 'Pinfu'),false);
});
