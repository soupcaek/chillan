# Chillan?

Sosial addon for vennegjengen i **WoW Forever**: hvem er online og hvor, felles LFG, gjengchat, leaderboard, feed, SOS, fiendelogg og mer – på tvers av guilds.

## Installer (én gang)

1. Last ned og installer **WowUp** fra [wowup.io](https://wowup.io) (versjon 2.24 eller nyere støtter Forever).
2. Åpne WowUp, velg **World of Warcraft: Forever** øverst.
3. Gå til **Get Addons → Install from URL** og lim inn:

   ```
   https://github.com/soupcaek/chillan
   ```

4. Start spillet og skriv `/chill`. Lim inn gjengkoden du har fått, og trykk **Bli med**.

Har du installert Chillan manuelt fra zip før: slett den gamle mappen `Chillan` i `_forever_\Interface\AddOns` først.

## Oppdateringer

WowUp viser **Update** når det kommer en ny versjon. Chillan sier også fra i spillet hvis en venn har nyere versjon enn deg.

## Kommandoer

| Kommando | Hva den gjør |
|---|---|
| `/chill` | Åpne/lukk vinduet |
| `/cg tekst` | Skriv i gjengchatten |
| `/chill sos` | Send SOS (blir ganket) |
| `/chill kveld` | Oppsummering av økten |
| `/chill fiende notat` | Legg målet ditt i fiendeloggen |
| `/chill legg til Navn` | Send hei til en venn som ikke dukker opp |
| `/chill minibar` | Vis/skjul minibaren |
| `/chill debug` | Teknisk status |

## For utvikler: ny versjon

Endre tallet i `VERSION` (f.eks. `0.2.0`) og push til `main`. GitHub Actions lager taggen `v0.2.0`, bygger zip-filen med BigWigs-packageren og legger den ut som release.

Font: Inter (SIL Open Font License).
