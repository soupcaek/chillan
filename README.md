# Chillan?

Sosial addon for vennegjengen i **WoW Forever**: hvem er online og hvor, gjengchat, statistikk og race til 60, ding med gratulasjoner, mats-tavle, avstemning og avtaler, feed, SOS, fiendelogg og mer – på tvers av guilds.

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

Hurtigtaster for å åpne Chillan, gjengchatten og SOS kan settes under **Esc → Options → Keybindings → AddOns**.

## Nytt i 0.5

- 175 achievements i 14 kategorier (bronse, sølv, gull og legendarisk), med egen fane «Trofeer»
- Popup med reaksjoner når noen i gjengen låser opp sølv eller bedre; bronse vises i chatten
- Achievement-poeng i statistikktabellen og på spillersiden
- Automatisk oppdagelse av venner via Battle.net og vennelista
- Dødsvarsel med «Hahaha!», «RIP», «Noob!» og «F», og versjonsnummer i tittellinja

## Nytt i 0.4

- Klikk på en venn for et hurtigkort (XP per time, tid til neste level, i dag, streak) og «Åpne spiller» for full statistikk
- «Min side» med din egen statistikk
- Varsler, ding-kort, SOS, oppsummering og minibar kan dras dit du vil (posisjonen huskes)
- Raskere chat og ingen «avlogging» når noen bytter layer eller sone

## Nytt i 0.2

- Minimap-knapp
- Ding midt på skjermen med «Gratulerer!», «GZ!» og «Endelig!»
- Statistikk: race til 60, level over tid, tabell og morsomme fakta
- Tavle: mats-tavle, avstemning og avtaler (LFG er fjernet)
- Ukens utfordring roterer mellom levels, quests, gull og PvP-kills
- Karakternavn hentes automatisk (kallenavn er fjernet)
- Mer lesbart profilkort

## For utvikler: ny versjon

Endre tallet i `VERSION` (f.eks. `0.2.0`) og push til `main`. GitHub Actions lager taggen `v0.2.0`, bygger zip-filen med BigWigs-packageren og legger den ut som release.

Font: Inter (SIL Open Font License).
