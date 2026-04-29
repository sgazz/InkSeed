# InkSeed — Glavne karakteristike i implementirano stanje

## Kratak opis igre
InkSeed je potezna strategijska igra crtanja za iPad/iOS, gde igrači prave poteze slobodnim linijama između tačaka (ili loop na istoj tački), zatim ubacuju novu tačku na nacrtanu liniju i tako šire mrežu dok protivnik ne ostane bez legalnog poteza.

## Gameplay flow (implementirano)
- **Welcome ekran** sa brendom i ulazom u novu partiju.
- **Setup faza**: postavljanje početnih tačaka direktnim tapom na tablu.
  - Ograničenje: **3 do 6** početnih tačaka.
  - Podržan `Undo` poslednje setup tačke.
- **Play faza** sa potezima u dve etape:
  - **Phase A**: igrač crta liniju između dve postojeće tačke ili loop.
  - **Phase B**: igrač tapne po toj liniji i ubaci novu tačku (linija se deli na dve).
- **Pobednik**: kada nema potencijala za dalji potez po pravilima stepena i validacije poteza.

## Pravila i validacija poteza (implementirano)
- **Stepen čvora (degree)**
  - Maksimalni stepen po tački: **3**.
  - Loop koristi +2 stepena na istoj tački.
  - Standardna veza koristi +1 na start i +1 na end tački.
- **Validacija linije**
  - Linija ne sme da seče niti da dodiruje postojeće linije.
  - Linija ne sme da prolazi preblizu nevezanim tačkama.
  - Endpoints se snap-uju na postojeće tačke uz toleranciju.
- **Shared-endpoint logika**
  - Ugrađen je poseban tretman zajedničkih endpoint-ova (trim/exclusion zona) da dozvoli prirodne izlaze iz istog čvora, ali da i dalje blokira realna preklapanja i preseke.
- **Ubacivanje nove tačke na pending liniju**
  - Dozvoljeno samo ako je tap dovoljno blizu linije.
  - Blokirano ako je nova tačka preblizu već postojećim tačkama.
- **Provera legalnih poteza**
  - Enumeracija kandidata uključuje:
    - petlje (više radijusa),
    - direktne veze između čvorova,
    - blage Bezier krive između parova čvorova.

## Input i interakcija (implementirano)
- Custom `PencilInputLayer` (`UIViewRepresentable`) za:
  - tap input u setup i placement fazi,
  - stroke input u drawing fazi.
- Podržan Apple Pencil i finger input (`allowFingerInput`).
- Live feedback tokom poteza:
  - live stroke preview,
  - invalid move poruke,
  - pending potez vizuelizacija.

## Vizuelni sloj i UX (implementirano)
- **Board rendering** preko SwiftUI `Canvas`:
  - postojeće linije sa “ink” stilom (undertone + varijacija debljine),
  - čvorovi kao hollow ring elementi,
  - pulse animacija na novododatoj tački.
- **Theme/brand sloj**:
  - premium “paper” pozadina sa suptilnim grain efektom,
  - light/dark theme toggle.
- **Top bar kontrole**:
  - `New Game`, `Restart`, `Help`, mod switch (`Premium`/`Junior`), theme toggle.
- **Bottom bar kontrole**:
  - setup i play footeri, fazni hint, provera poteza, collapse/expand ponašanje.
- **Help sheet** sa MVP pravilima.

## Paint the Match režim (implementirano)
- Kada partija ima pobednika, otključava se **“Paint the Match 🎨”**.
- Interaktivno bojenje zatvorenih regiona table:
  - detekcija regiona flood-fill pristupom nad raster maskom,
  - odbijanje otvorenih/propusnih/već popunjenih ili premalih regiona,
  - anti-gap logika (morphological closing + small-gap bridges) za stabilnije popunjavanje.
- Funkcije:
  - izbor palete (Junior i Premium varijante),
  - `Undo` poslednjeg fill-a,
  - `Clear` svih fill-ova,
  - `Share` slike,
  - `Save` u Photos (uz permission flow),
  - `Done` povratak u igru.

## Tehnička arhitektura (implementirano)
- **State management**
  - `GameState` (`@MainActor`, `ObservableObject`) kao centralni game state.
  - `BoardInteractionState` za UI interakcije i feedback.
- **Modeli**
  - `DotModel`, `EdgeModel`, `ProcessedStroke`, `PendingMove`.
- **Engine slojevi**
  - `StrokeProcessing`: smoothing + simplification + endpoint snap.
  - `RulesEngine`: potpuna validacija poteza i pretraga legalnih poteza.
  - `Geometry` utili i `GeometryProfile` za tunable tolerancije.

## Testovi (implementirano)
- XCTest regresioni testovi za `RulesEngine` sa fokusom na shared-endpoint ponašanje:
  - legalni potezi iz već povezanog čvora,
  - legalan izlaz pod malim uglom,
  - detekcija ilegalnog preklapanja,
  - detekcija ilegalnog presecanja nakon napuštanja endpoint zone.
