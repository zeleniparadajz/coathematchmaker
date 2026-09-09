export interface LeagueMatch {
  player1: { toString(): string };
  player2: { toString(): string };
  winner?: { toString(): string };
  round: string;
  status: string;
  sets: { player1Games: number; player2Games: number }[];
}

export const leagueRankingRules =
  "Pobjede; pobjede u međusobnim mečevima igrača sa istim brojem pobjeda; razlika setova; razlika gemova; redoslijed prijave.";

export function roundRobinTable(participants: string[], matches: LeagueMatch[]) {
  const rows = participants.map((playerId, index) => ({
    playerId, seed: index + 1, played: 0, wins: 0, losses: 0,
    setsWon: 0, setsLost: 0, gamesWon: 0, gamesLost: 0, headToHeadWins: 0,
    registrationOrder: index
  }));
  const byId = new Map(rows.map((row) => [row.playerId, row]));
  const confirmed = matches.filter((m) => m.round === "RR" && m.status === "confirmed" && m.winner);
  for (const match of confirmed) {
    const a = byId.get(String(match.player1));
    const b = byId.get(String(match.player2));
    if (!a || !b || a === b || ![a.playerId, b.playerId].includes(String(match.winner))) continue;
    a.played++; b.played++;
    const winner = String(match.winner) === a.playerId ? a : b;
    const loser = winner === a ? b : a;
    winner.wins++; loser.losses++;
    for (const set of match.sets) {
      a.gamesWon += set.player1Games; a.gamesLost += set.player2Games;
      b.gamesWon += set.player2Games; b.gamesLost += set.player1Games;
      if (set.player1Games > set.player2Games) { a.setsWon++; b.setsLost++; }
      if (set.player2Games > set.player1Games) { b.setsWon++; a.setsLost++; }
    }
  }
  for (const match of confirmed) {
    const a = byId.get(String(match.player1));
    const b = byId.get(String(match.player2));
    if (a && b && a.wins === b.wins) {
      const winner = byId.get(String(match.winner));
      if (winner === a || winner === b) winner.headToHeadWins++;
    }
  }
  rows.sort((a, b) => b.wins - a.wins || b.headToHeadWins - a.headToHeadWins ||
    (b.setsWon - b.setsLost) - (a.setsWon - a.setsLost) ||
    (b.gamesWon - b.gamesLost) - (a.gamesWon - a.gamesLost) || a.registrationOrder - b.registrationOrder);
  return rows.map((row, index) => ({ ...row, seed: index + 1 }));
}

export function leagueCompletionProblem(participants: string[], matches: LeagueMatch[]): string | null {
  if (participants.length < 2) return "Potrebna su najmanje dva učesnika.";
  const expected = participants.length * (participants.length - 1) / 2;
  const league = matches.filter((m) => m.round === "RR");
  if (league.length !== expected) return "Liga mora imati po jedan meč svakog para učesnika.";
  const pairs = new Set<string>();
  for (const match of league) {
    const a = String(match.player1), b = String(match.player2);
    const pair = [a, b].sort().join(":");
    if (a === b || !participants.includes(a) || !participants.includes(b) || pairs.has(pair)) {
      return "Liga ima duplirane ili neispravne parove.";
    }
    pairs.add(pair);
    if (match.status !== "confirmed" || !match.winner || ![a, b].includes(String(match.winner)) || !match.sets.length) {
      return "Svi ligaški mečevi moraju imati potvrđen rezultat.";
    }
  }
  return null;
}

export function seededPairs(seeds: string[]): string[][] {
  if (![2, 4, 8, 16].includes(seeds.length)) throw new Error("Unsupported knockout size");
  let order = [1, 2];
  while (order.length < seeds.length) {
    const sum = order.length * 2 + 1;
    order = order.flatMap((seed) => [seed, sum - seed]);
  }
  return Array.from({ length: order.length / 2 }, (_, i) => [seeds[order[i * 2] - 1], seeds[order[i * 2 + 1] - 1]]);
}
